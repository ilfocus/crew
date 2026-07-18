# Crew Makefile
# 管理 crew_gui Flutter macOS 应用的设置、启动、停止、重启。
#
# 常用命令:
#   make setup     安装所有依赖
#   make start     后台启动 crew_gui
#   make stop      停止 crew_gui
#   make restart   重启 crew_gui
#   make run       前台运行 (支持热重载, 按 q 退出)
#   make logs      跟踪后台日志
#   make test      运行所有测试
#   make clean     清理构建产物

APP_NAME  := crew_gui
GUI_DIR   := crew_gui
CORE_DIR  := crew_core
CLI_DIR   := crew_cli
PID_FILE  := .run.pid
LOG_FILE  := .run.log

.PHONY: help setup start stop restart run logs test clean

.DEFAULT_GOAL := help

help: ## 显示帮助
	@echo "Crew Makefile — 管理 crew_gui Flutter macOS 应用"
	@echo ""
	@echo "常用命令:"
	@echo "  make setup     安装所有依赖 (crew_core / crew_cli / crew_gui)"
	@echo "  make start     后台启动 crew_gui (日志: $(LOG_FILE))"
	@echo "  make stop      停止正在运行的 crew_gui"
	@echo "  make restart   重启 crew_gui"
	@echo "  make run       前台运行 crew_gui (支持热重载, 按 q 退出)"
	@echo "  make logs      跟踪后台运行日志"
	@echo "  make test      运行所有测试"
	@echo "  make clean     清理构建产物"

setup: ## 安装所有依赖
	@echo "==> 安装依赖..."
	@cd $(CORE_DIR) && flutter pub get
	@cd $(CLI_DIR) && flutter pub get
	@cd $(GUI_DIR)  && flutter pub get
	@echo "==> 依赖安装完成."

start: ## 后台启动 crew_gui
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "crew_gui 已在运行 (PID: $$(cat $(PID_FILE))). 使用 'make restart' 重启."; \
		exit 1; \
	fi
	@echo "==> 启动 crew_gui..."
	@cd $(GUI_DIR) && nohup flutter run -d macos > ../$(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE)
	@sleep 1
	@echo "==> 已启动 (PID: $$(cat $(PID_FILE)))."
	@echo "    日志: $(LOG_FILE)"
	@echo "    停止: make stop"

run: ## 前台运行 crew_gui (支持热重载)
	@cd $(GUI_DIR) && flutter run -d macos

stop: ## 停止 crew_gui
	@echo "==> 停止 crew_gui..."
	@if [ -f $(PID_FILE) ]; then \
		pid=$$(cat $(PID_FILE)); \
		if kill -0 $$pid 2>/dev/null; then \
			kill $$pid 2>/dev/null || true; \
			echo "    已停止 flutter 进程 (PID: $$pid)."; \
		else \
			echo "    PID $$pid 已不存在, 清理 pid 文件."; \
		fi; \
		rm -f $(PID_FILE); \
	fi
	@-pkill -x $(APP_NAME) 2>/dev/null && echo "    已停止 macOS 应用进程." || true
	@echo "==> 停止完成."

restart: ## 重启 crew_gui
	@$(MAKE) stop
	@sleep 1
	@$(MAKE) start

logs: ## 跟踪后台日志
	@if [ -f $(LOG_FILE) ]; then \
		tail -f $(LOG_FILE); \
	else \
		echo "日志文件不存在: $(LOG_FILE) (是否未运行 'make start'?)"; \
	fi

test: ## 运行所有测试
	@echo "==> 运行 crew_core 测试..."
	@cd $(CORE_DIR) && dart test
	@echo "==> 运行 crew_cli 测试..."
	@cd $(CLI_DIR) && dart test
	@echo "==> 运行 crew_gui 测试..."
	@cd $(GUI_DIR) && flutter test

clean: ## 清理构建产物
	@echo "==> 清理构建产物..."
	@cd $(CORE_DIR) && flutter clean 2>/dev/null || true
	@cd $(CLI_DIR)  && flutter clean 2>/dev/null || true
	@cd $(GUI_DIR)  && flutter clean
	@rm -f $(PID_FILE) $(LOG_FILE)
	@echo "==> 清理完成."
