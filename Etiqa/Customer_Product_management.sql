set serveroutput on;
declare
  v_custId NUMBER;
  v_productId NUMBER;
  v_orderId NUMBER;
  v_bookQuantity NUMBER;
  outOfStock_error EXCEPTION;
  
  v_Name VARCHAR2(50) := 'Kev';
  v_Last_name VARCHAR2(50) := 'Sarmi';
  v_Email VARCHAR2(100) := 'test12@gmail.com';
  
  v_BookTitle VARCHAR2(100) := 'Test Book Vol 1';
  v_BookPrice NUMBER(10, 2) := 12.31;
  v_Quantity NUMBER := 5;
  
  i_order_custId NUMBER := 1;
  i_order_bookTitle VARCHAR2(200) := 'Test Book Vol 1';
  
  cursor c_orders is 
      select orderId, first_name, last_name, email, book_title, orderdate
        from Orders 
          natural join Customers 
          natural join Products;
  type t_orders is table of c_orders%ROWTYPE;
  order_list t_orders;
  
begin

  -- Insert new Customer
  insert into Customers ( First_Name, Last_Name, Email)
  values (v_Name, v_Last_name, utl_raw.cast_to_raw(v_Email));

  -- Insert a new book in Products
  insert into Products (Book_Title, Book_Price, Book_Quantity)
  values (v_BookTitle, v_BookPrice, v_Quantity);
  commit; 
  
  --CREATING NEW ORDER--
   -- Validation
  select CustomerID into v_custId from Customers where CustomerID = i_order_custId;
  select ProductID, Book_Quantity into v_productId, v_bookQuantity from Products where Book_Title = i_order_bookTitle;
  
  if v_bookQuantity = 1 then
    raise outOfStock_error;
  end if;

  -- Processing of new order
  update Products set Book_Quantity = Book_Quantity - 1 where ProductID = v_productId;
  insert into Orders (CustomerID, ProductID) values (v_custId, v_productId) returning OrderID into v_orderId;
  
  dbms_output.put_line('Order successfully created! Order ID: ' || v_orderId);
  
  commit;

  -- List all existing Orders --
  open c_orders;
  loop
    fetch c_orders bulk collect into order_list limit 100;
    for l_indx IN 1..order_list.count loop
       dbms_output.put_line('Order ID: "' || order_list(l_indx).orderId || 
                            '", Name: "' ||  order_list(l_indx).first_name || ' ' ||  order_list(l_indx).last_name ||
                            '" Email: "' || utl_raw.cast_to_varchar2(order_list(l_indx).email) ||
                            '", Book Title: "' ||  order_list(l_indx).Book_Title ||
                            '" Order Date: "' ||  order_list(l_indx).orderdate || '"');
    end loop;
  exit when c_orders%notfound;
  end loop;
  close c_orders;  
  
exception
  when no_data_found then
    dbms_output.put_line('CustomerID: "'|| i_order_custId || '" OR Book Title: "' || i_order_bookTitle || '" does not exist in the Database!');
  when outOfStock_error then
    dbms_output.put_line('Book Title: "' || i_order_bookTitle || '" is out of stock!');
    rollback;
  when others then
     dbms_output.put_line(sqlerrm);
     rollback;
end;
/

---- Schedule Job: Delete all book which are out of stock ----
begin
    dbms_scheduler.create_job (
        job_name        => 'book_clean_up',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'begin delete from Products where Book_Quantity =0; end;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=15; BYMINUTE=08; BYSECOND=0',
        enabled         => TRUE
    );
end;
/
