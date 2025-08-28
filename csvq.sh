#!/bin/sh
# Define AWK command variable (can be replaced with gawk/mawk or other paths)
AWK="awk"  # Default to system awk, can be overridden by environment variable
SQL="$*"
SQL="${SQL%;}"  # Remove trailing semicolon (compatible with some SQL syntax)

# Get column number for specified column in table (starting from 1)
get_column_number() {
    table=$1
    column=$2
    # Use $AWK to process the first row
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
        # Parse table name and column definitions
        table_part=$(echo "$SQL" | sed -n 's/create table \([a-zA-Z0-9_]*\)[ ]*(\(.*\))/\1:\2/p')
        table=$(echo "$table_part" | cut -d: -f1)
        columns=$(echo "$table_part" | cut -d: -f2 | tr -d ' ')
        # Create CSV file and write column headers
        echo "$columns" > "$table.csv"
        echo "Created table: $table"
        ;;
    "insert into "*)
        # Parse table name and insert values
        table=$(echo "$SQL" | sed -n 's/insert into \([a-zA-Z0-9_]*\).*/\1/p')
        # Clean value format (remove spaces/quotes)
        values=$(echo "$SQL" | sed -n "s/.*values[ ]*(\([^)]*\)).*/\1/p" | $AWK -F, -v OFS=, '{
            for(i=1; i<=NF; i++) {
                gsub(/^[[:space:]\047"]+/, "", $i);
                gsub(/[[:space:]\047"]+$/, "", $i);
            }
            print
        }')
        # Append data to CSV file
        echo "$values" >> "$table.csv"
        echo "Inserted 1 row into $table"
        ;;
    "select * from "*)
        table=$(echo "$SQL" | sed -n 's/select \* from \([a-zA-Z0-9_]*\).*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')
        if [ -n "$where" ]; then
            # Parse WHERE condition
            field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
            value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
            col=$(get_column_number "$table" "$field")
            # Use $AWK to filter data
            $AWK -F, -v col="$col" -v val="$value" '
            BEGIN {OFS=FS}
            NR==1 || $col == val {print}
            ' "$table.csv"
        else
            # No condition, output entire table directly
            cat "$table.csv"
        fi
        ;;
    "update "*)
        table=$(echo "$SQL" | sed -n 's/update \([a-zA-Z0-9_]*\).*/\1/p')
        set_clauses=$(echo "$SQL" | sed -n 's/.*set \(.*\) where.*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')
        # Parse WHERE condition
        where_field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
        where_value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
        where_col=$(get_column_number "$table" "$where_field")
        # Parse SET clause
        old_IFS="$IFS"
        IFS=','
        set -- $set_clauses
        # Dynamically generate AWK script
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
        # Use $AWK to process and update data
        $AWK -F, "$awk_script" "$table.csv" > tmp.csv && mv tmp.csv "$table.csv"
        echo "Updated $table"
        ;;
    "delete from "*)
        table=$(echo "$SQL" | sed -n 's/delete from \([a-zA-Z0-9_]*\).*/\1/p')
        where=$(echo "$SQL" | sed -n 's/.*where \(.*\)/\1/p')
        # Parse WHERE condition
        field=$(echo "$where" | cut -d= -f1 | tr -d ' ')
        value=$(echo "$where" | cut -d= -f2 | tr -d "'\"")
        col=$(get_column_number "$table" "$field")
        # Use $AWK to filter data
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