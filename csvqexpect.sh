#!/usr/bin/env expect
# Test suite configuration
set timeout 5
set script_name "./csvq.sh"
spawn bash

# Test helper functions
proc test_cmd {desc cmd expected} {
    puts "\n=== Testing: $desc ==="
    send "$cmd\r"
    expect {
        timeout { 
            puts "FAIL: $desc (timeout)"
            return 0
        }
        -re $expected {
            puts "PASS: $desc"
            return 1
        }
        eof {
            puts "FAIL: $desc (unexpected exit)"
            return 0
        }
    }
}

proc cleanup_files {} {
    send "rm -f *.csv tmp.csv\r"
    expect "$ "
}

# Test counters
set total_tests 0
set passed_tests 0

# Test macro
proc run_test {desc cmd expected} {
    global total_tests passed_tests
    incr total_tests
    if {[test_cmd $desc $cmd $expected]} {
        incr passed_tests
    }
}

puts "Starting Shell SQL Test Suite..."

# Clean up environment
cleanup_files

# Test 1: Create table
run_test "Create user table" \
    "$script_name \"create table users(id,name,age)\"" \
    "Created table: users"

# Verify CSV file creation
run_test "Verify CSV file content" \
    "cat users.csv" \
    "id,name,age"

# Test 2: Insert data
run_test "Insert user data 1" \
    "$script_name \"insert into users values(1,'Alice',25)\"" \
    "Inserted 1 row into users"

run_test "Insert user data 2" \
    "$script_name \"insert into users values(2,'Bob',30)\"" \
    "Inserted 1 row into users"

run_test "Insert user data 3" \
    "$script_name \"insert into users values(3,'Charlie',35)\"" \
    "Inserted 1 row into users"

# Test 3: Query all data
run_test "Query all users" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,25.*2,Bob,30.*3,Charlie,35"

# Test 4: Conditional queries
run_test "Query user by ID" \
    "$script_name \"select * from users where id=2\"" \
    "id,name,age.*2,Bob,30"

run_test "Query user by name" \
    "$script_name \"select * from users where name=Alice\"" \
    "id,name,age.*1,Alice,25"

# Test 5: Update data
run_test "Update user age" \
    "$script_name \"update users set age=26 where id=1\"" \
    "Updated users"

# Verify update results
run_test "Verify update results" \
    "$script_name \"select * from users where id=1\"" \
    "id,name,age.*1,Alice,26"

# Test 6: Multi-field update
run_test "Update user multiple fields" \
    "$script_name \"update users set name=Robert,age=31 where id=2\"" \
    "Updated users"

run_test "Verify multi-field update" \
    "$script_name \"select * from users where id=2\"" \
    "id,name,age.*2,Robert,31"

# Test 7: Delete data
run_test "Delete user" \
    "$script_name \"delete from users where id=3\"" \
    "Deleted from users"

# Verify deletion results
run_test "Verify deletion results" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,26.*2,Robert,31"

# Test 8: Error handling
run_test "Unsupported SQL statement" \
    "$script_name \"drop table users\"" \
    "Error: Unsupported SQL"

# Test 9: Create another table to test isolation
run_test "Create product table" \
    "$script_name \"create table products(pid,pname,price)\"" \
    "Created table: products"

run_test "Insert product data" \
    "$script_name \"insert into products values(101,'Laptop',999.99)\"" \
    "Inserted 1 row into products"

run_test "Query product data" \
    "$script_name \"select * from products\"" \
    "pid,pname,price.*101,Laptop,999.99"

# Verify table isolation
run_test "Verify table isolation" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,26.*2,Robert,31"

# Test 10: Edge cases - null values and special characters
run_test "Insert data with spaces" \
    "$script_name \"insert into users values(4, 'John Doe', 28)\"" \
    "Inserted 1 row into users"

run_test "Verify space handling" \
    "$script_name \"select * from users where name='John Doe'\"" \
    "id,name,age.*4,John Doe,28"

# Test 11: SQL statement trailing semicolon handling
run_test "SQL statement with semicolon" \
    "$script_name \"select * from users where id=1;\"" \
    "id,name,age.*1,Alice,26"

# Report test results
puts "\n" 
puts "=========================================="
puts "Testing completed!"
puts "Total tests: $total_tests"
puts "Passed tests: $passed_tests"
puts "Failed tests: [expr $total_tests - $passed_tests]"
puts "Success rate: [expr round($passed_tests * 100.0 / $total_tests)]%"
puts "=========================================="

# Clean up test files
cleanup_files

if {$passed_tests == $total_tests} {
    puts "All tests passed! ✓"
    exit 0
} else {
    puts "Some tests failed! ✗"
    exit 1
}