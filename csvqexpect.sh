#!/usr/bin/env expect

# 测试套装配置
set timeout 5
set script_name "csvq.sh"
spawn bash

# 测试辅助函数
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

# 测试计数器
set total_tests 0
set passed_tests 0

# 测试宏
proc run_test {desc cmd expected} {
    global total_tests passed_tests
    incr total_tests
    if {[test_cmd $desc $cmd $expected]} {
        incr passed_tests
    }
}

puts "开始 Shell SQL 测试套装..."

# 清理环境
cleanup_files

# 测试1: 创建表
run_test "创建用户表" \
    "$script_name \"create table users(id,name,age)\"" \
    "Created table: users"

# 验证CSV文件创建
run_test "验证CSV文件内容" \
    "cat users.csv" \
    "id,name,age"

# 测试2: 插入数据
run_test "插入用户数据1" \
    "$script_name \"insert into users values(1,'Alice',25)\"" \
    "Inserted 1 row into users"

run_test "插入用户数据2" \
    "$script_name \"insert into users values(2,'Bob',30)\"" \
    "Inserted 1 row into users"

run_test "插入用户数据3" \
    "$script_name \"insert into users values(3,'Charlie',35)\"" \
    "Inserted 1 row into users"

# 测试3: 查询所有数据
run_test "查询所有用户" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,25.*2,Bob,30.*3,Charlie,35"

# 测试4: 条件查询
run_test "按ID查询用户" \
    "$script_name \"select * from users where id=2\"" \
    "id,name,age.*2,Bob,30"

run_test "按姓名查询用户" \
    "$script_name \"select * from users where name=Alice\"" \
    "id,name,age.*1,Alice,25"

# 测试5: 更新数据
run_test "更新用户年龄" \
    "$script_name \"update users set age=26 where id=1\"" \
    "Updated users"

# 验证更新结果
run_test "验证更新结果" \
    "$script_name \"select * from users where id=1\"" \
    "id,name,age.*1,Alice,26"

# 测试6: 多字段更新
run_test "更新用户多字段" \
    "$script_name \"update users set name=Robert,age=31 where id=2\"" \
    "Updated users"

run_test "验证多字段更新" \
    "$script_name \"select * from users where id=2\"" \
    "id,name,age.*2,Robert,31"

# 测试7: 删除数据
run_test "删除用户" \
    "$script_name \"delete from users where id=3\"" \
    "Deleted from users"

# 验证删除结果
run_test "验证删除结果" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,26.*2,Robert,31"

# 测试8: 错误处理
run_test "不支持的SQL语句" \
    "$script_name \"drop table users\"" \
    "Error: Unsupported SQL"

# 测试9: 创建另一个表测试隔离性
run_test "创建产品表" \
    "$script_name \"create table products(pid,pname,price)\"" \
    "Created table: products"

run_test "插入产品数据" \
    "$script_name \"insert into products values(101,'Laptop',999.99)\"" \
    "Inserted 1 row into products"

run_test "查询产品数据" \
    "$script_name \"select * from products\"" \
    "pid,pname,price.*101,Laptop,999.99"

# 验证表隔离性
run_test "验证表隔离性" \
    "$script_name \"select * from users\"" \
    "id,name,age.*1,Alice,26.*2,Robert,31"

# 测试10: 边界情况 - 空值和特殊字符
run_test "插入包含空格的数据" \
    "$script_name \"insert into users values(4, 'John Doe', 28)\"" \
    "Inserted 1 row into users"

run_test "验证空格处理" \
    "$script_name \"select * from users where name='John Doe'\"" \
    "id,name,age.*4,John Doe,28"

# 测试11: SQL语句末尾分号处理
run_test "SQL语句带分号" \
    "$script_name \"select * from users where id=1;\"" \
    "id,name,age.*1,Alice,26"

# 报告测试结果
puts "\n" 
puts "=========================================="
puts "测试完成!"
puts "总测试数: $total_tests"
puts "通过测试: $passed_tests"
puts "失败测试: [expr $total_tests - $passed_tests]"
puts "成功率: [expr round($passed_tests * 100.0 / $total_tests)]%"
puts "=========================================="

# 清理测试文件
cleanup_files

if {$passed_tests == $total_tests} {
    puts "所有测试通过! ✓"
    exit 0
} else {
    puts "部分测试失败! ✗"
    exit 1
}
