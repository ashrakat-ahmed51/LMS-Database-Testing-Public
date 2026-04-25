Create database LibraryDB;
use LibraryDB;
Create TABLE books(
	book_id INT PRIMARY KEY AUTO_INCREMENT,
	book_title VARCHAR(50) NOT NULL,
    book_author VARCHAR(50) NOT NULL,
    book_category VARCHAR(50),
    book_ISBN VARCHAR(20) NOT NULL UNIQUE,
    book_publish_year INT,
    book_quantity INT DEFAULT 0 CHECK (book_quantity >= 0)
);


CREATE TABLE members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(50) NOT NULL,
    email VARCHAR(50) NOT NULL UNIQUE,
    phone VARCHAR(20),
	membership_date DATE DEFAULT (CURDATE())
);

CREATE TABLE borrowing (
    borrowing_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    book_id INT NOT NULL,
    borrow_date DATE DEFAULT (CURDATE()),
    due_date DATE DEFAULT (DATE_ADD(CURDATE(), INTERVAL 14 DAY)),
    return_date DATE,
    
    status VARCHAR(20) DEFAULT 'Borrowed',
    
    CONSTRAINT fk_member
        FOREIGN KEY (member_id) REFERENCES members(member_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_book
        FOREIGN KEY (book_id) REFERENCES books(book_id)
        ON DELETE CASCADE
);

DELIMITER $$

CREATE TRIGGER prevent_borrow_when_zero
BEFORE INSERT ON borrowing
FOR EACH ROW
BEGIN
    DECLARE qty INT;

    SELECT book_quantity INTO qty
    FROM books
    WHERE book_id = NEW.book_id;

    IF qty <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Borrowing failed: Book quantity is zero.';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER prevent_excess_borrowing
BEFORE INSERT ON borrowing
FOR EACH ROW
BEGIN
    DECLARE active_count INT;

    SELECT COUNT(*) INTO active_count
    FROM borrowing
    WHERE member_id = NEW.member_id
      AND status = 'Borrowed'
      AND return_date IS NULL;

    IF active_count >= 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Borrowing failed: Member already borrowed 5 active books.';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER decrease_book_quantity
AFTER INSERT ON borrowing
FOR EACH ROW
BEGIN
    UPDATE books
    SET book_quantity = book_quantity - 1
    WHERE book_id = NEW.book_id;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER increase_quantity_after_return
AFTER UPDATE ON borrowing
FOR EACH ROW
BEGIN
    -- Only run if return_date changed from NULL to NOT NULL
    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        
        -- Increase book quantity
        UPDATE books
        SET book_quantity = book_quantity + 1
        WHERE book_id = NEW.book_id;

    END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER mark_late_return
BEFORE UPDATE ON borrowing
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL
       AND NEW.return_date > NEW.due_date THEN
        SET NEW.status = 'Late Return';
    END IF;
END$$

DELIMITER ;



#Happy scenarios testcases
#TC-01 
INSERT INTO books (book_title, book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ('The Great Gatsby', 'F. Scott Fitzgerald', 'Fiction', '9780743273565', 1925, 5);

select * from books

#TC-2 
INSERT INTO members (full_name, email, phone)
VALUES ('Omar Ashraf', 'omar@example.com', '01119158385');
select * from members

#TC-3 
INSERT INTO borrowing (member_id, book_id)
VALUES (1, 1);
SELECT * FROM borrowing;
SELECT * FROM books;


#TC-4 
UPDATE borrowing
SET return_date = CURDATE(),
	status = 'Returned'
WHERE borrowing_id = 1;
SELECT * FROM borrowing;


#TC-5
UPDATE borrowing
SET return_date = '2025-12-10'
WHERE borrowing_id = 2;
SELECT * FROM borrowing;
SELECT * FROM books;

#TC-6
#Using member ID 
SELECT 
    b.borrowing_id,
    b.member_id,
    m.full_name AS member_name,
    b.book_id,
    bo.book_title,
    b.borrow_date,
    b.due_date,
    b.return_date,
    b.status
FROM borrowing b
JOIN members m ON b.member_id = m.member_id
JOIN books bo ON b.book_id = bo.book_id
WHERE b.member_id = 1;


#TC-7
SELECT 
    b.borrowing_id,
    b.member_id,
    m.full_name AS member_name,
    b.book_id,
    bo.book_title,
    b.borrow_date,
    b.due_date,
    b.return_date,
    b.status
FROM borrowing b
JOIN members m ON b.member_id = m.member_id
JOIN books bo ON b.book_id = bo.book_id
WHERE b.member_id = 1;

#TC-8
#View Overdue Books
SELECT b.borrowing_id, b.member_id, m.full_name, b.book_id, bo.book_title, b.borrow_date, b.due_date, b.status
FROM borrowing b
JOIN members m ON b.member_id = m.member_id
JOIN books bo ON b.book_id = bo.book_id
WHERE b.return_date IS NULL AND b.due_date < CURDATE();

#TC-9
#View Currently Borrowed Books
SELECT b.borrowing_id, b.member_id, m.full_name, b.book_id, bo.book_title, b.borrow_date, b.due_date, b.status
FROM borrowing b
JOIN members m ON b.member_id = m.member_id
JOIN books bo ON b.book_id = bo.book_id
WHERE b.return_date IS NULL;


#Negative scenarios 
#TC-10
INSERT INTO books (book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ( 'Mary Beard', 'History', '9780887765543', 2012, 9);
select * from books


#TC-11
INSERT INTO books (book_title , book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ( 'Ancient Civilizations','History', '9780887765543', 2012, 9);
select * from books

#TC-12 
INSERT INTO books (book_author, book_title , book_category, book_publish_year, book_quantity)
VALUES ( 'Mary Beard', 'Ancient Civilizations','History', 2012, 9);
select * from books


#TC-13
INSERT INTO books (book_title, book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ('Ancient Civilizations', 'Mary Beard', 'History', '9780887765545', 2012, -3);
select * from books

#TC-14
INSERT INTO books (book_title, book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ('Quantum Realities', 'Brian Greene', 'Science', '9780743273565', 2019, 5);
select * from books

#TC-15
INSERT INTO books (book_title, book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ('The Art of Cooking', 'Julia Child', 'Cooking', '974sdadsa', 1999, 10);
SELECT * FROM books;

#TC-16
INSERT INTO members (email, phone)
VALUES ('ahmedaa@example.com', '01119134576');
select * from members

#TC-17
INSERT INTO members ( full_name , phone)
VALUES ('Omar Ashraf', '01119134576');
select * from members

#TC-18
INSERT INTO members (full_name, email, phone)
VALUES ('Ahmed Adel345', 'ahmdga@example.com', '01116168676');
SELECT * FROM members;

#TC-19
INSERT INTO members (full_name, email, phone)
VALUES ('Ahmed Adel', 'ahmdgaexamplecom', '01116134576');
SELECT * FROM members;

#TC-20
INSERT INTO members ( full_name ,email, phone)
VALUES ('Khaled Mohammed', 'khaledassa@example.com','011195abds');
select * from members


#TC-21
INSERT INTO members ( full_name ,email, phone)
VALUES ('Omar Mohammed', 'omar@example.com','01119156385');
select * from members

#TC-22
INSERT INTO borrowing (member_id, book_id)
VALUES (2, 5);
SELECT * FROM borrowing;
SELECT * FROM books;

#TC-23
INSERT INTO borrowing (member_id, book_id)
VALUES (3, 8)
SELECT * FROM borrowing;
SELECT * FROM books;

#TC-24
UPDATE borrowing
SET return_date = '2025-11-18',
	status = 
WHERE borrowing_id = 999;
SELECT * FROM borrowing;

#TC-25
SELECT 
    borrowing_id,
    borrow_date,
    '2025-11-10' AS attempted_return_date,
    CASE  
        WHEN '2025-11-10' < borrow_date THEN 'Invalid: return date is before borrow date'
        ELSE 'Valid return date'
    END AS validation_result
FROM borrowing
WHERE borrowing_id = 8;

SELECT * FROM borrowing;


#TC-26 
INSERT INTO books (book_title, book_author, book_category, book_ISBN, book_publish_year, book_quantity)
VALUES ('Cooking with Passion', 'Maria Lopez', 'Cooking', '9786645123982', 2df012, 5);

#TC 27
SELECT 
    borrowing_id,
    borrow_date,
    due_date,
    CASE 
        WHEN DATEDIFF(due_date, borrow_date) = 14 THEN ' Due date is correct'
        ELSE 'Due date is NOT correct'
    END AS validation_result
FROM borrowing
WHERE borrowing_id = 1;


