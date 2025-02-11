@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM 定义目标目录
SET "REPO_PATH=%USERPROFILE%\Desktop\GitHub\sh"

REM 检查目标目录是否存在
IF NOT EXIST "%REPO_PATH%" (
    echo ===========================================
    echo 错误：目录 %REPO_PATH% 不存在，请检查路径！
    echo ===========================================
    pause
    EXIT /B 1
)

REM 切换到目标目录
CD /D "%REPO_PATH%"

REM 检查是否为有效的 Git 仓库
IF NOT EXIST .git (
    echo ===========================================
    echo 错误：目录 %REPO_PATH% 不是一个有效的 Git 仓库。
    echo ===========================================
    pause
    EXIT /B 1
)

REM 确保当前分支是 main 分支
git rev-parse --abbrev-ref HEAD >nul 2>&1
IF ERRORLEVEL 1 (
    echo ===========================================
    echo 错误：无法检测当前分支，请确保这是一个有效的 Git 仓库。
    echo ===========================================
    pause
    EXIT /B 1
)

SET CURRENT_BRANCH=main
git checkout %CURRENT_BRANCH% >nul 2>&1
IF ERRORLEVEL 1 (
    echo ===========================================
    echo 错误：无法切换到分支 %CURRENT_BRANCH%，请检查分支名称。
    echo ===========================================
    pause
    EXIT /B 1
)

REM 检查远程仓库是否有更新
echo ===========================================
echo 正在检查远程仓库是否有更新...
git fetch origin %CURRENT_BRANCH%

IF NOT "!ERRORLEVEL!"=="0" (
    echo 错误：无法从远程仓库获取更新，请检查网络连接或远程配置。
    pause
    EXIT /B 1
)

REM 比较本地分支与远程分支
SET REMOTE_BRANCH=origin/%CURRENT_BRANCH%
git rev-list --left-right --count %REMOTE_BRANCH%...%CURRENT_BRANCH% >nul 2>&1
FOR /F "tokens=1,2 delims=	" %%A IN ('git rev-list --left-right --count %REMOTE_BRANCH%...%CURRENT_BRANCH%') DO (
    SET BEHIND_COUNT=%%A
    SET AHEAD_COUNT=%%B
)

echo ===========================================
echo 本地分支与远程分支的差异：
echo 当前分支落后远程分支 !BEHIND_COUNT! 次提交。
echo 当前分支领先远程分支 !AHEAD_COUNT! 次提交。
echo ===========================================

REM 如果有更新，则拉取更改
IF !BEHIND_COUNT! GTR 0 (
    echo 正在从远程仓库拉取更新...
    git pull origin %CURRENT_BRANCH%
    IF "!ERRORLEVEL!"=="0" (
        echo 更新成功！
    ) ELSE (
        echo 错误：拉取更新失败，请手动检查。
    )
) ELSE (
    echo 本地分支已经是最新状态，无需更新。
)

echo ===========================================
echo 脚本执行完成。
pause
ENDLOCAL