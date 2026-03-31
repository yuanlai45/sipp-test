#!/bin/bash

# 定义变量
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="$WORKSPACE/logs"
SERVER_PORT=8080
SERVER_PID_FILE="/tmp/sipp_report_server.pid"

# 显示帮助信息
function show_help() {
    echo "SIPp测试报告查看工具"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  start    启动报告服务器"
    echo "  stop     停止报告服务器"
    echo "  status   查看服务器状态"
    echo "  list     列出可用报告"
    echo "  fix      修复报告文件编码问题"
    echo "  help     显示此帮助信息"
}

# 检查依赖
function check_dependencies() {
    if ! command -v python3 &>/dev/null; then
        echo "错误: 需要安装Python 3"
        echo "请运行: sudo apt install python3"
        exit 1
    fi
}

# 查找所有HTML报告
function find_reports() {
    echo "查找测试报告..."
    echo "----------------------------------------"
    
    local reports=($(find "$REPORTS_DIR" -name "*_report.html" -type f))
    local count=${#reports[@]}
    
    if [ $count -eq 0 ]; then
        echo "未找到测试报告"
        return 1
    fi
    
    echo "找到 $count 份测试报告:"
    echo
    
    for ((i=0; i<$count; i++)); do
        local report="${reports[$i]}"
        local relative_path="${report#$WORKSPACE/}"
        local report_name=$(basename "$report")
        local mod_time=$(stat -c "%y" "$report")
        
        echo "[$i] $report_name"
        echo "    路径: $relative_path"
        echo "    修改时间: $mod_time"
        echo
    done
    
    return 0
}

# 获取主机IP地址
function get_host_ip() {
    # 尝试获取主机IP地址
    local ip=$(hostname -I | awk '{print $1}')
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    echo $ip
}

# 启动报告服务器
function start_server() {
    # 检查服务器是否已经运行
    if [ -f "$SERVER_PID_FILE" ] && kill -0 $(cat "$SERVER_PID_FILE") 2>/dev/null; then
        echo "服务器已经在运行，PID: $(cat "$SERVER_PID_FILE")"
        return 0
    fi
    
    echo "启动报告HTTP服务器 (端口: $SERVER_PORT)..."
    
    # 创建索引页面
    create_index_page
    
    # 启动Python HTTP服务器
    cd "$WORKSPACE" && python3 -m http.server $SERVER_PORT > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$SERVER_PID_FILE"
    
    echo "服务器已启动，PID: $pid"
    
    # 显示访问URL
    local ip=$(get_host_ip)
    echo
    echo "您可以通过以下URL访问报告:"
    echo "http://$ip:$SERVER_PORT/logs/report_index.html"
    echo
    echo "按Ctrl+C停止服务器"
    
    return 0
}

# 创建索引页面
function create_index_page() {
    local index_file="$REPORTS_DIR/report_index.html"
    local reports=($(find "$REPORTS_DIR" -name "*_report.html" -type f))
    
    # 确保使用UTF-8编码创建文件
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="UTF-8">
    <title>SIPp测试报告索引</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        .report-list { margin: 20px 0; }
        .report-item { 
            border: 1px solid #ddd; 
            padding: 15px; 
            margin-bottom: 10px; 
            border-radius: 5px;
            background-color: #f9f9f9;
        }
        .report-title { font-weight: bold; color: #2980b9; }
        .report-path { color: #7f8c8d; font-size: 0.9em; }
        .report-time { color: #7f8c8d; font-size: 0.8em; }
        a { color: #3498db; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .header { 
            background-color: #34495e; 
            color: white; 
            padding: 20px; 
            margin-bottom: 20px; 
            border-radius: 5px;
        }
        .footer { 
            margin-top: 30px; 
            padding-top: 10px; 
            border-top: 1px solid #eee; 
            color: #7f8c8d; 
            font-size: 0.8em; 
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>SIPp测试报告索引</h1>
        <p>生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>
    
    <h2>可用报告 (${#reports[@]})</h2>
    
    <div class="report-list">
EOF
    
    if [ ${#reports[@]} -eq 0 ]; then
        cat >> "$index_file" << EOF
        <p>未找到任何测试报告</p>
EOF
    else
        for report in "${reports[@]}"; do
            local relative_path="${report#$WORKSPACE/}"
            local report_name=$(basename "$report")
            local mod_time=$(stat -c "%y" "$report")
            local report_type="未知"
            
            if [[ "$report_name" == *"resource"* ]]; then
                report_type="资源监控报告"
            elif [[ "$report_name" == *"error"* ]]; then
                report_type="错误统计报告"
            fi
            
            cat >> "$index_file" << EOF
        <div class="report-item">
            <div class="report-title">$report_type - $report_name</div>
            <div class="report-path">路径: $relative_path</div>
            <div class="report-time">修改时间: $mod_time</div>
            <p><a href="/$relative_path" target="_blank">查看报告 →</a></p>
        </div>
EOF
        done
    fi
    
    cat >> "$index_file" << EOF
    </div>
    
    <div class="footer">
        <p>SIPp测试套件 - 报告查看器</p>
        <p>您可以通过命令 <code>bash scripts/view_reports.sh stop</code> 停止此服务器</p>
    </div>
</body>
</html>
EOF
    
    echo "创建了索引页面: $index_file"
}

# 停止报告服务器
function stop_server() {
    if [ ! -f "$SERVER_PID_FILE" ]; then
        echo "服务器未运行"
        return 0
    fi
    
    local pid=$(cat "$SERVER_PID_FILE")
    if kill -0 $pid 2>/dev/null; then
        echo "停止报告服务器 (PID: $pid)..."
        kill $pid
        rm -f "$SERVER_PID_FILE"
        echo "服务器已停止"
    else
        echo "服务器未运行 (PID文件可能已过期)"
        rm -f "$SERVER_PID_FILE"
    fi
    
    return 0
}

# 显示服务器状态
function show_status() {
    if [ ! -f "$SERVER_PID_FILE" ]; then
        echo "服务器未运行"
        return 1
    fi
    
    local pid=$(cat "$SERVER_PID_FILE")
    if kill -0 $pid 2>/dev/null; then
        local ip=$(get_host_ip)
        echo "服务器正在运行 (PID: $pid)"
        echo "访问URL: http://$ip:$SERVER_PORT/logs/report_index.html"
        return 0
    else
        echo "服务器未运行 (PID文件可能已过期)"
        rm -f "$SERVER_PID_FILE"
        return 1
    fi
}

# 修复报告文件的编码问题
function fix_report_encoding() {
    echo "正在修复报告文件编码..."
    
    local reports=($(find "$REPORTS_DIR" -name "*_report.html" -type f))
    local count=${#reports[@]}
    
    if [ $count -eq 0 ]; then
        echo "未找到需要修复的报告"
        return 1
    fi
    
    echo "找到 $count 份报告文件需要修复"
    
    for report in "${reports[@]}"; do
        echo "修复: $report"
        
        # 检查文件是否已经包含UTF-8编码声明
        if grep -q "<meta.*charset.*UTF-8" "$report"; then
            echo "  已包含UTF-8编码声明，跳过"
            continue
        fi
        
        # 创建临时文件
        local temp_file="${report}.tmp"
        
        # 添加UTF-8编码声明
        awk 'BEGIN{fixed=0} 
        /<head>/ && !fixed {
            print $0;
            print "    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">";
            print "    <meta charset=\"UTF-8\">";
            fixed=1;
            next;
        }
        {print}' "$report" > "$temp_file"
        
        # 如果没有找到<head>标签，则在文件开头添加
        if ! grep -q "<meta.*charset.*UTF-8" "$temp_file"; then
            awk 'BEGIN{printed=0} 
            /<!DOCTYPE html>/ || /<html>/ || /<HTML>/ {
                if(!printed) {
                    print $0;
                    print "<head>";
                    print "    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">";
                    print "    <meta charset=\"UTF-8\">";
                    print "</head>";
                    printed=1;
                    next;
                }
            }
            {print}' "$report" > "$temp_file"
        fi
        
        # 替换原文件
        mv "$temp_file" "$report"
        echo "  已修复"
    done
    
    echo "编码修复完成"
    return 0
}

# 主函数
function main() {
    check_dependencies
    
    case "$1" in
        start)
            start_server
            ;;
        stop)
            stop_server
            ;;
        status)
            show_status
            ;;
        list)
            find_reports
            ;;
        fix)  # 新增命令
            fix_report_encoding
            ;;
        *)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"
