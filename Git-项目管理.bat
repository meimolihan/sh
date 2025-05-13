@echo off
color 0A

:MENU
color 0A
cls
echo ==============================
echo         Git 项目管理脚本
echo ==============================
echo 1. 检查Git仓库状态
echo 2. 提交并推送更改
echo 3. 拉取远程更新
echo ==============================
echo 0. 退出
echo ==============================
    set "choice="
    set /p choice="请输入操作编号 (0 - 3): "
    if not defined choice (
        echo 输入不能为空，请输入（0 - 3）之间的数字。
        timeout /t 2 >nul
		rem 定义要返回的菜单
        goto menu
    )

if "%choice%"=="1" goto CHECK_STATUS
if "%choice%"=="2" goto COMMIT_PUSH
if "%choice%"=="3" goto PULL_UPDATE
if "%choice%"=="0" goto EXIT_SCRIPT

echo 无效选项，请重新选择...
pause
goto MENU

:CHECK_STATUS
echo 正在检查Git仓库状态...
git status
echo 检查完成！请根据提示确认文件状态。
pause
goto MENU

:COMMIT_PUSH
echo 提交并推送更改：
set /p commit_msg=请输入提交信息（直接回车默认为 "update"）： 
if "%commit_msg%"=="" set commit_msg=update

echo 正在添加所有更改到暂存区...
git add .
echo 添加完成！

echo 正在提交更改，提交信息为：%commit_msg%
git commit -m "%commit_msg%"
echo 提交完成！

echo 正在推送更改到远程仓库...
git push
echo 推送完成！您的更改已成功同步到远程仓库。

pause
goto MENU

:PULL_UPDATE
echo 正在从远程仓库拉取更新...
git pull
if %errorlevel% equ 0 (
    echo 拉取成功！本地仓库已是最新版本。
) else (
    echo 拉取失败！请检查网络或远程仓库地址是否正确。
)
pause
goto MENU

:EXIT_SCRIPT
echo 脚本已退出，感谢使用！
exit