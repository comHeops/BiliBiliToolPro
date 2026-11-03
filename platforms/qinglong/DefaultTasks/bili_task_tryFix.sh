#!/usr/bin/env bash
# cron:0 0 1 1 *
# new Env("bili尝试修复异常")

QL_DIR=${QL_DIR:-"/ql"}
dir_shell=$QL_DIR/shell
# 青龙有 share.sh；呆呆面板等非青龙环境没有，这里允许缺失，后面自行兜底目录
if [ -f "$dir_shell/share.sh" ]; then
    . "$dir_shell/share.sh"
fi
touch /root/.bashrc 2>/dev/null && . /root/.bashrc 2>/dev/null || true

bili_repo=${BILI_REPO:-"raywangqvq/bilibilitoolpro"}
bili_branch=${BILI_BRANCH:-""}

dir_repo=${dir_repo:-"$QL_DIR/data/repo"}
if [ ! -d "$dir_repo" ] && [ -d "$QL_DIR/repo" ]; then
    dir_repo="$QL_DIR/repo"
fi
if [ -n "${BILI_REPO_DIR:-}" ]; then
    dir_repo="$BILI_REPO_DIR"
fi

echo "青龙repo目录: $dir_repo"
qinglong_bili_repo="$(echo "$bili_repo" | sed 's/\//_/g')${bili_branch}"
qinglong_bili_repo_dir=""

# 与 bili_task_base.sh 保持一致：优先按脚本自身位置定位仓库，
# 兼容呆呆面板等直接在订阅检出目录里执行脚本的面板
bili_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd || true)"
bili_repo_candidate="$(cd "$bili_script_dir/../../.." >/dev/null 2>&1 && pwd || true)"
if [ -n "$bili_repo_candidate" ] && [ -d "$bili_repo_candidate/platforms/qinglong/DefaultTasks" ]; then
    qinglong_bili_repo_dir="$bili_repo_candidate"
fi

if [ -z "$qinglong_bili_repo_dir" ]; then
    qinglong_bili_repo_dir="$(find "$dir_repo" -type d \( -iname "$qinglong_bili_repo" -o -iname "${qinglong_bili_repo}_main" \) 2>/dev/null | head -1 || true)"
fi
if [ -z "$qinglong_bili_repo_dir" ] && [ -d "$dir_repo" ]; then
    qinglong_bili_repo_dir="$(find "$dir_repo" -maxdepth 4 -type d -iname "bilibilitoolpro" 2>/dev/null | head -1 || true)"
fi
if [ -z "$qinglong_bili_repo_dir" ] && [ -d "$dir_repo" ]; then
    bili_solution_file="$(find "$dir_repo" -maxdepth 5 -type f -name "Ray.BiliBiliTool.sln" 2>/dev/null | head -1 || true)"
    if [ -n "$bili_solution_file" ]; then
        qinglong_bili_repo_dir="$(dirname "$bili_solution_file")"
    fi
fi
echo "bili仓库目录: $qinglong_bili_repo_dir"

if [ -z "$qinglong_bili_repo_dir" ]; then
    echo "未找到 bili 仓库目录"
    echo "查找目标：$qinglong_bili_repo"
    echo "已搜索目录：$dir_repo"
    echo "请确认已拉取仓库 ${bili_repo}${bili_branch}，或通过环境变量 BILI_REPO / BILI_BRANCH / BILI_REPO_DIR 覆盖默认值"
    exit 1
fi

echo -e "清理缓存...\n"
cd "$qinglong_bili_repo_dir"
find . -type d -name "bin" -exec rm -rf {} +
find . -type d -name "obj" -exec rm -rf {} +
echo -e "清理完成\n"

get_dotnet_major_version() {
    local dotnet_command="${1:-dotnet}"
    local dotnet_version
    # Respect SDK selection (including global.json) and reject failed commands.
    dotnet_version="$("$dotnet_command" --version 2>/dev/null)" || return 1
    # Some wrappers return SDK-list rows instead of one selected version.
    printf '%s\n' "$dotnet_version" | awk '
        /^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+(-[[:alnum:].-]+)?(\+[[:alnum:].-]+)?([[:space:]]+\[[^]]+\])?[[:space:]]*$/ {
            split($1, version, ".")
            if (version[1] + 0 > highest) highest = version[1] + 0
        }
        END {
            if (highest > 0) print highest
            else exit 1
        }
    '
}

echo "检测dotnet..."
requiredDotnetMajor=10
dotnetMajor="$(get_dotnet_major_version dotnet || true)"
echo "当前dotnet主版本：${dotnetMajor:-未检测到可用SDK}"
if [[ "$dotnetMajor" =~ ^[0-9]+$ && "$dotnetMajor" -ge "$requiredDotnetMajor" ]]; then
    echo "已安装，且版本满足"
else
    echo "which dotnet: $(which dotnet)"
    echo "Path: $PATH"
    if ! bash "$qinglong_bili_repo_dir/platforms/qinglong/ray-dotnet-install.sh"; then
        echo "安装 .NET $requiredDotnetMajor SDK 失败"
        exit 1
    fi
    . /root/.bashrc
    dotnetMajor="$(get_dotnet_major_version dotnet || true)"
    if ! [[ "$dotnetMajor" =~ ^[0-9]+$ && "$dotnetMajor" -ge "$requiredDotnetMajor" ]]; then
        echo ".NET $requiredDotnetMajor SDK 安装后不可用"
        exit 1
    fi
    echo "当前dotnet主版本：$dotnetMajor"
fi
echo "检测dotnet结束"