#!/bin/sh

# 定义 AWK 命令变量（可替换为 gawk/mawk 或其他路径）
AWK="awk"  # 默认使用系统 awk，可通过环境变量覆盖

SQL="$*"
SQL="${SQL%;}"  # 移除末尾分号（兼容部分SQL写法）

# 获取表中指定列的列号（从1开始）
get_column_number() {
    table=$1
    column=$2
    # 使用 $AWK 处理首行
    head -1 "$table.csv" | $AWK -F, -v col="$column" '{
        for (i=1; i<=NF; i++){
            if ($i == col) {
                print i
                exit
            }
        }
    }'
}

case "$SQL" in
    "create table "*)
        # 解析表名和列定义
        table_part=$(echo "$SQL" | sed -n 's/create table \([a-zA-Z0-9_]*\)[ ]*(\(.*\))/\1:\2/p')
        table=$(echo "$table_part" | cut -d: -f1)
        columns=$(echo "$table_part" | cut -d: -f2 | tr -d ' ')
        # 创建CSV文件并写入列头
        echo "$columns" > "$table.csv"
        echo "Created table: $table"
        ;;

    "insert into "*)
        # 解析表名和插入值
        table=$(echo "$SQL" | sed -n 's/insert into \([a-zA-Z0-9_]*\).*/\1/p')
        # 清理值的格式（去空格/引号）
        values=$(echo "$SQL" | sed -n "s/.*values[ ]*(\([^)]*\)).*/\1/p" | $AWK -F, -v OFS=, '{
            for(i=1; i<=NF; i++) {
                gsub(/^[[:space:]\047"]+/, "", $i);
                gsub(/[[:space:]\047"]+$/, "", $i);
            }
            print
        }')
        # 追加数据到CSV文件
        echo "$values" >> "$table.csv"
        echo "Inserted 1 row into $table"
        ;;

    "select * from "*)
        table=$(echo "$SQL" | sed -n 's/select \* from \([a-zA-Z0-9_]*\).*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')

        if [ -n "$where" ]; then
            # 解析WHERE条件
            field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
            value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
            col=$(get_column_number "$table" "$field")
            # 使用 $AWK 过滤数据
            $AWK -F, -v col="$col" -v val="$value" '
            BEGIN {OFS=FS}
            NR==1 || $col == val {print}
            ' "$table.csv"
        else
            # 无条件直接输出全表
            cat "$table.csv"
        fi
        ;;

    "update "*)
        table=$(echo "$SQL" | sed -n 's/update \([a-zA-Z0-9_]*\).*/\1/p')
        set_clauses=$(echo "$SQL" | sed -n 's/.*set \(.*\) where.*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')

        # 解析WHERE条件
        where_field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
        where_value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
        where_col=$(get_column_number "$table" "$where_field")

        # 解析SET子句
        old_IFS="$IFS"
        IFS=','
        set -- $set_clauses
        # 动态生成AWK脚本
        awk_script='
        BEGIN {OFS=FS}
        NR==1 {print; next}
        $'"$where_col"' == "'"$where_value"'" {
        '
        for kv in "$@"; do
            key=$(echo "$kv" | $AWK -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')
            val=$(echo "$kv" | $AWK -F= '{gsub(/^[[:space:]\047"]+|[[:space:]\047"]+$/,"",$2); print $2}')
            col=$(get_column_number "$table" "$key")
            awk_script="$awk_script \$$col=\"$val\";"
        done
        IFS="$old_IFS"

        awk_script='
        '$awk_script'
        }
        {print}
        '

        # 使用 $AWK 处理并更新数据
        $AWK -F, "$awk_script" "$table.csv" > tmp.csv && mv tmp.csv "$table.csv"
        echo "Updated $table"
        ;;

    "delete from "*)
        table=$(echo "$SQL" | sed -n 's/delete from \([a-zA-Z0-9_]*\).*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')

        # 解析WHERE条件
        field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
        value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
        col=$(get_column_number "$table" "$field")

        # 使用 $AWK 过滤数据
        $AWK -F, -v col="$col" -v val="$value" '
        BEGIN {OFS=FS}
        NR==1 || $col != val {print}
        ' "$table.csv" > tmp.csv && mv tmp.csv "$table.csv"
        echo "Deleted from $table"
        ;;

    *)
        echo "Error: Unsupported SQL - $SQL"
        exit 1
        ;;
esac