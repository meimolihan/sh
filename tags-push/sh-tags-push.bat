@echo off
REM Windows 批处理脚本：更新 Git 标签

REM 设置颜色为绿色背景，默认亮白色文字
COLOR 0A
CLS
PROMPT $P$G

REM 设置 Git 仓库路径
SET REPO_PATH=%USERPROFILE%\Desktop\GitHub\sh

REM 切换到指定的 Git 仓库目录
CD /D %REPO_PATH%

REM 检查是否成功切换到仓库目录
IF NOT EXIST .git (
    echo ===========================================
    echo 错误：目录 %REPO_PATH% 不是一个有效的 Git 仓库。
    echo ===========================================
    pause
    EXIT /B 1
)

REM 添加所有更改并提交
echo ===========================================
echo 正在添加所有更改...
git add .
echo ===========================================
echo 正在提交更改，提交信息为 "update"...
git commit -m "update"
echo ===========================================

REM 推送提交到远程仓库
echo 正在将提交推送到远程仓库...
git push
echo ===========================================

REM 删除本地标签 v1.0.0
echo 正在删除本地标签 v1.0.0...
git tag -d v1.0.0
echo ===========================================

REM 删除远程标签 v1.0.0
echo 正在删除远程标签 v1.0.0...
git push origin :refs/tags/v1.0.0
echo ===========================================

REM 检查标签是否删除成功
echo 检查标签 v1.0.0 是否删除成功...
git tag -l | findstr /I "v1.0.0" >nul
IF %ERRORLEVEL% EQU 0 (
    echo 远程标签 v1.0.0 删除失败，请手动检查。
) ELSE (
    echo 远程标签 v1.0.0 删除成功。
)
echo ===========================================

REM 创建新标签 v1.0.0
echo 正在创建新标签 v1.0.0，标签信息为 "为最新提交的重新创建标签"...
git tag -a v1.0.0 -m "Recreate tags for the latest submission"
echo ===========================================

REM 推送新标签到远程仓库
echo 正在将新的标签 v1.0.0 推送到远程仓库...
git push origin v1.0.0
echo ===========================================

REM 检查标签是否推送成功
echo 检查标签 v1.0.0 是否推送成功...
git tag -l | findstr /I "v1.0.0" >nul
IF %ERRORLEVEL% EQU 0 (
    echo 标签 v1.0.0 推送成功。
) ELSE (
    echo 标签 v1.0.0 推送失败，请手动检查。
)
echo ===========================================

echo 所有操作已完成。
pause