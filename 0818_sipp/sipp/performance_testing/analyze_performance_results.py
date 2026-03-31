#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
SIPP性能测试结果分析工具
功能：解析SIPP统计数据，生成性能报告和趋势分析
"""

import csv
import json
import os
import sys
import argparse
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime
from pathlib import Path

class SippPerformanceAnalyzer:
    def __init__(self, test_results_dir):
        self.test_results_dir = Path(test_results_dir)
        self.analysis_results = {}
    
    def parse_stats_csv(self, csv_file):
        """解析SIPP统计CSV文件"""
        if not csv_file.exists():
            return None
        
        try:
            df = pd.read_csv(csv_file, delimiter=';')
            if df.empty:
                return None
            
            # 获取最后一行数据（最终统计）
            final_stats = df.iloc[-1].to_dict()
            
            # 计算关键指标
            total_calls = int(final_stats.get('TotalCallCreated', 0))
            successful_calls = int(final_stats.get('SuccessfulCall', 0))
            failed_calls = int(final_stats.get('FailedCall', 0))
            
            success_rate = (successful_calls / total_calls * 100) if total_calls > 0 else 0
            
            return {
                'total_calls': total_calls,
                'successful_calls': successful_calls,
                'failed_calls': failed_calls,
                'success_rate': round(success_rate, 2),
                'call_rate': float(final_stats.get('CallRate', 0)),
                'current_calls': int(final_stats.get('CurrentCall', 0)),
                'incoming_calls': int(final_stats.get('IncomingCall', 0)),
                'outgoing_calls': int(final_stats.get('OutgoingCall', 0)),
                'elapsed_time': final_stats.get('ElapsedTime', '0'),
                'failed_reasons': {
                    'cannot_send_message': int(final_stats.get('FailedCannotSendMessage', 0)),
                    'max_udp_retrans': int(final_stats.get('FailedMaxUDPRetrans', 0)),
                    'unexpected_message': int(final_stats.get('FailedUnexpectedMessage', 0)),
                    'call_rejected': int(final_stats.get('FailedCallRejected', 0)),
                    'cmd_not_sent': int(final_stats.get('FailedCmdNotSent', 0)),
                    'regexp_no_match': int(final_stats.get('FailedRegexpDoesntMatch', 0))
                },
                'response_times': {
                    'avg_response_time': float(final_stats.get('ResponseTimeRepartition1', 0)),
                    'avg_call_length': float(final_stats.get('CallLengthRepartition1', 0))
                }
            }
        except Exception as e:
            print(f"解析统计文件失败 {csv_file}: {e}")
            return None
    
    def analyze_single_test(self, test_dir):
        """分析单个测试结果"""
        test_path = Path(test_dir)
        if not test_path.exists():
            return None
        
        print(f"分析测试: {test_path.name}")
        
        # 解析UAC统计
        uac_stats = self.parse_stats_csv(test_path / 'uac' / 'stats.csv')
        
        # 解析UAS统计
        uas_stats = self.parse_stats_csv(test_path / 'uas' / 'stats.csv')
        
        # 读取错误日志
        uac_errors = self.count_errors(test_path / 'uac' / 'errors.log')
        uas_errors = self.count_errors(test_path / 'uas' / 'errors.log')
        
        # 获取测试时间信息
        test_info = self.extract_test_info(test_path)
        
        analysis = {
            'test_id': test_path.name,
            'test_info': test_info,
            'uac_stats': uac_stats,
            'uas_stats': uas_stats,
            'error_summary': {
                'uac_errors': uac_errors,
                'uas_errors': uas_errors,
                'total_errors': uac_errors + uas_errors
            }
        }
        
        # 保存分析结果
        analysis_file = test_path / 'analysis' / 'detailed_analysis.json'
        analysis_file.parent.mkdir(exist_ok=True)
        with open(analysis_file, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)
        
        return analysis
    
    def count_errors(self, error_log_file):
        """统计错误日志中的错误数量"""
        if not error_log_file.exists():
            return 0
        
        try:
            with open(error_log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                # 简单统计非空行数作为错误数
                return len([line for line in lines if line.strip()])
        except:
            return 0
    
    def extract_test_info(self, test_path):
        """提取测试基本信息"""
        # 从目录名解析时间戳
        dir_name = test_path.name
        if 'test_run_' in dir_name:
            timestamp_str = dir_name.replace('test_run_', '')
            try:
                test_time = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                return {
                    'start_time': test_time.strftime('%Y-%m-%d %H:%M:%S'),
                    'timestamp': timestamp_str
                }
            except:
                pass
        
        return {
            'start_time': 'Unknown',
            'timestamp': dir_name
        }
    
    def analyze_all_tests(self):
        """分析所有测试结果"""
        test_dirs = [d for d in self.test_results_dir.iterdir() 
                    if d.is_dir() and d.name.startswith('test_run_')]
        
        if not test_dirs:
            print("未找到测试结果目录")
            return
        
        print(f"发现 {len(test_dirs)} 个测试结果")
        
        all_results = []
        for test_dir in sorted(test_dirs):
            result = self.analyze_single_test(test_dir)
            if result:
                all_results.append(result)
        
        # 生成汇总报告
        self.generate_summary_report(all_results)
        
        # 生成趋势分析
        self.generate_trend_analysis(all_results)
        
        return all_results
    
    def generate_summary_report(self, results):
        """生成汇总报告"""
        if not results:
            return
        
        print("生成汇总报告...")
        
        summary = {
            'total_tests': len(results),
            'test_period': {
                'start': results[0]['test_info']['start_time'],
                'end': results[-1]['test_info']['start_time']
            },
            'overall_performance': {
                'total_calls': sum(r['uac_stats']['total_calls'] for r in results if r['uac_stats']),
                'total_successful': sum(r['uac_stats']['successful_calls'] for r in results if r['uac_stats']),
                'total_failed': sum(r['uac_stats']['failed_calls'] for r in results if r['uac_stats']),
                'avg_success_rate': sum(r['uac_stats']['success_rate'] for r in results if r['uac_stats']) / len([r for r in results if r['uac_stats']]),
                'avg_call_rate': sum(r['uac_stats']['call_rate'] for r in results if r['uac_stats']) / len([r for r in results if r['uac_stats']])
            },
            'error_analysis': {
                'total_errors': sum(r['error_summary']['total_errors'] for r in results),
                'avg_errors_per_test': sum(r['error_summary']['total_errors'] for r in results) / len(results)
            }
        }
        
        # 保存汇总报告
        summary_file = self.test_results_dir / 'performance_summary.json'
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, indent=2, ensure_ascii=False)
        
        # 生成HTML报告
        self.generate_html_report(summary, results)
        
        print(f"汇总报告已保存: {summary_file}")
    
    def generate_html_report(self, summary, results):
        """生成HTML格式的报告"""
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>SIPP性能测试汇总报告</title>
    <style>
        body {{ font-family: 'Microsoft YaHei', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }}
        .metric-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 20px 0; }}
        .metric-card {{ background: #f8f9fa; border: 1px solid #e9ecef; border-radius: 6px; padding: 15px; }}
        .metric-value {{ font-size: 24px; font-weight: bold; color: #495057; }}
        .metric-label {{ font-size: 14px; color: #6c757d; margin-top: 5px; }}
        .success {{ color: #28a745; }}
        .warning {{ color: #ffc107; }}
        .error {{ color: #dc3545; }}
        .test-table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        .test-table th, .test-table td {{ border: 1px solid #dee2e6; padding: 8px; text-align: left; }}
        .test-table th {{ background-color: #e9ecef; }}
        .test-table tr:nth-child(even) {{ background-color: #f8f9fa; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 SIPP高性能压测汇总报告</h1>
            <p>测试期间: {summary['test_period']['start']} ~ {summary['test_period']['end']}</p>
            <p>总测试次数: {summary['total_tests']}</p>
        </div>
        
        <h2>📊 整体性能指标</h2>
        <div class="metric-grid">
            <div class="metric-card">
                <div class="metric-value success">{summary['overall_performance']['total_calls']}</div>
                <div class="metric-label">总呼叫数</div>
            </div>
            <div class="metric-card">
                <div class="metric-value success">{summary['overall_performance']['total_successful']}</div>
                <div class="metric-label">成功呼叫数</div>
            </div>
            <div class="metric-card">
                <div class="metric-value error">{summary['overall_performance']['total_failed']}</div>
                <div class="metric-label">失败呼叫数</div>
            </div>
            <div class="metric-card">
                <div class="metric-value {'success' if summary['overall_performance']['avg_success_rate'] > 95 else 'warning' if summary['overall_performance']['avg_success_rate'] > 90 else 'error'}">{summary['overall_performance']['avg_success_rate']:.2f}%</div>
                <div class="metric-label">平均成功率</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">{summary['overall_performance']['avg_call_rate']:.2f}</div>
                <div class="metric-label">平均呼叫速率 (calls/s)</div>
            </div>
            <div class="metric-card">
                <div class="metric-value error">{summary['error_analysis']['total_errors']}</div>
                <div class="metric-label">总错误数</div>
            </div>
        </div>
        
        <h2>📋 详细测试结果</h2>
        <table class="test-table">
            <thead>
                <tr>
                    <th>测试ID</th>
                    <th>开始时间</th>
                    <th>总呼叫数</th>
                    <th>成功率</th>
                    <th>呼叫速率</th>
                    <th>错误数</th>
                    <th>状态</th>
                </tr>
            </thead>
            <tbody>
        """
        
        for result in results:
            if result['uac_stats']:
                status_class = 'success' if result['uac_stats']['success_rate'] > 95 else 'warning' if result['uac_stats']['success_rate'] > 90 else 'error'
                status_text = '✅ 优秀' if result['uac_stats']['success_rate'] > 95 else '⚠️ 一般' if result['uac_stats']['success_rate'] > 90 else '❌ 较差'
                
                html_content += f"""
                <tr>
                    <td>{result['test_id']}</td>
                    <td>{result['test_info']['start_time']}</td>
                    <td>{result['uac_stats']['total_calls']}</td>
                    <td class="{status_class}">{result['uac_stats']['success_rate']:.2f}%</td>
                    <td>{result['uac_stats']['call_rate']:.2f}</td>
                    <td class="{'error' if result['error_summary']['total_errors'] > 0 else ''}">{result['error_summary']['total_errors']}</td>
                    <td>{status_text}</td>
                </tr>
                """
        
        html_content += """
            </tbody>
        </table>
        
        <div style="margin-top: 30px; padding: 15px; background-color: #e9ecef; border-radius: 6px;">
            <h3>📝 报告说明</h3>
            <ul>
                <li><strong>成功率 > 95%</strong>: 优秀 ✅</li>
                <li><strong>成功率 90-95%</strong>: 一般 ⚠️</li>
                <li><strong>成功率 < 90%</strong>: 较差 ❌</li>
            </ul>
        </div>
        
        <div style="margin-top: 20px; text-align: center; color: #6c757d; font-size: 12px;">
            报告生成时间: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """
        </div>
    </div>
</body>
</html>
        """
        
        html_file = self.test_results_dir / 'performance_report.html'
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"HTML报告已保存: {html_file}")
    
    def generate_trend_analysis(self, results):
        """生成趋势分析图表"""
        if len(results) < 2:
            print("测试数据不足，跳过趋势分析")
            return
        
        print("生成趋势分析图表...")
        
        # 准备数据
        test_ids = [r['test_id'] for r in results]
        success_rates = [r['uac_stats']['success_rate'] for r in results if r['uac_stats']]
        call_rates = [r['uac_stats']['call_rate'] for r in results if r['uac_stats']]
        total_calls = [r['uac_stats']['total_calls'] for r in results if r['uac_stats']]
        
        # 设置中文字体
        plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
        plt.rcParams['axes.unicode_minus'] = False
        
        # 创建图表
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle('SIPP性能测试趋势分析', fontsize=16, fontweight='bold')
        
        # 成功率趋势
        ax1.plot(range(len(success_rates)), success_rates, 'o-', color='green', linewidth=2)
        ax1.set_title('成功率趋势')
        ax1.set_ylabel('成功率 (%)')
        ax1.set_xlabel('测试轮次')
        ax1.grid(True, alpha=0.3)
        ax1.set_ylim(0, 100)
        
        # 呼叫速率趋势
        ax2.plot(range(len(call_rates)), call_rates, 'o-', color='blue', linewidth=2)
        ax2.set_title('呼叫速率趋势')
        ax2.set_ylabel('呼叫速率 (calls/s)')
        ax2.set_xlabel('测试轮次')
        ax2.grid(True, alpha=0.3)
        
        # 总呼叫数趋势
        ax3.bar(range(len(total_calls)), total_calls, color='orange', alpha=0.7)
        ax3.set_title('总呼叫数分布')
        ax3.set_ylabel('总呼叫数')
        ax3.set_xlabel('测试轮次')
        ax3.grid(True, alpha=0.3)
        
        # 错误数趋势
        error_counts = [r['error_summary']['total_errors'] for r in results]
        ax4.plot(range(len(error_counts)), error_counts, 'o-', color='red', linewidth=2)
        ax4.set_title('错误数趋势')
        ax4.set_ylabel('错误数')
        ax4.set_xlabel('测试轮次')
        ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        # 保存图表
        chart_file = self.test_results_dir / 'performance_trends.png'
        plt.savefig(chart_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"趋势分析图表已保存: {chart_file}")

def main():
    parser = argparse.ArgumentParser(description='SIPP性能测试结果分析工具')
    parser.add_argument('results_dir', help='测试结果目录路径')
    parser.add_argument('--single', help='分析单个测试结果', metavar='TEST_DIR')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.results_dir):
        print(f"错误: 结果目录不存在: {args.results_dir}")
        sys.exit(1)
    
    analyzer = SippPerformanceAnalyzer(args.results_dir)
    
    if args.single:
        # 分析单个测试
        single_test_path = os.path.join(args.results_dir, args.single)
        result = analyzer.analyze_single_test(single_test_path)
        if result:
            print(f"单个测试分析完成: {args.single}")
            print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(f"分析失败: {args.single}")
    else:
        # 分析所有测试
        results = analyzer.analyze_all_tests()
        print(f"分析完成，共处理 {len(results) if results else 0} 个测试结果")

if __name__ == '__main__':
    main()
