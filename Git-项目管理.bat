@echo off
color 0A

:MENU
color 0A
cls
echo ==============================
echo         Git 项目管理脚本
echo ==============================
echo * 1. 检查当前仓库状态
echo.
echo * 2. 推送当前仓库更改
echo.
echo * 3. 拉取当前仓库更新
echo.
echo * 4. 更改当前仓库标签
echo ==============================
echo * 5. 推送所有仓库更新
echo.
echo * 6. 拉取所有仓库更新
echo.
echo * 7. 克隆所有仓库菜单
echo ==============================
echo * 0. 退出
echo ==============================
set /p choice="请输入操作编号 (0 - 7): "


if "%choice%"=="1" goto CHECK_STATUS
if "%choice%"=="2" goto COMMIT_PUSH
if "%choice%"=="3" goto PULL_UPDATE
if "%choice%"=="4" goto UPDATE_GIT_TAG
if "%choice%"=="5" goto GIT_PUSH_ALL
if "%choice%"=="6" goto GIT_PUSH_ALL
if "%choice%"=="7" goto GIT_CLONE_ALL
if "%choice%"=="0" goto EXIT_SCRIPT

echo 无效选项，请重新选择...
pause
goto MENU

echo ============= 一 、 检查Git仓库状态 =================
:CHECK_STATUS
cls
echo ==============================
echo      正在检查Git仓库状态...
echo ==============================
git status
echo ==============================
echo 检查完成！请根据提示确认文件状态。
echo ==============================
pause
goto MENU

echo ============= 二 、提交并推送更改 =================
:COMMIT_PUSH
cls
echo ========================================
echo              提交并推送更改
echo ========================================

set /p commit_msg=请输入提交信息（直接回车默认为 "update"）： 
if "%commit_msg%"=="" set commit_msg=update

echo ========================================
echo 正在添加所有更改到暂存区...
git add .
echo 添加完成！

echo ========================================
echo 正在提交更改，提交信息为：%commit_msg%
git commit -m "%commit_msg%"
echo 提交完成！

echo ========================================
echo 正在推送更改到远程仓库...
git push
echo 推送完成！您的更改已成功同步到远程仓库。

echo ========================================
pause
goto MENU

echo ============= 三 、拉取远程更新 =================
:PULL_UPDATE
cls
echo ========================================
echo          正在从远程仓库拉取更新...
echo ========================================
git pull
if %errorlevel% equ 0 (
    echo 拉取成功！本地仓库已是最新版本。
) else (
    echo 拉取失败！请检查网络或远程仓库地址是否正确。
)
echo ========================================
pause
goto MENU


echo ============= 四 、提交并更新标签 =================
:UPDATE_GIT_TAG
cls
REM 使用当前目录作为Git仓库路径
SET REPO_PATH=%CD%

echo 当前仓库路径：%REPO_PATH%
echo ==============================

REM 检查是否为有效的Git仓库
IF NOT EXIST .git (
    echo 错误：当前目录 %REPO_PATH% 不是一个有效的Git仓库。
    echo ==============================
    pause
    EXIT /B 1
)

REM 添加所有更改并提交
echo       正在添加所有更改...
git add .
echo ==============================
echo 正在提交更改，提交信息为 "update"...
git commit -m "update"
echo ==============================

REM 推送提交到远程仓库
echo 正在将提交推送到远程仓库...
git push
echo ==============================

REM 删除本地标签 v1.0.0
echo 正在删除本地标签 v1.0.0...
git tag -d v1.0.0
echo ==============================

REM 删除远程标签 v1.0.0
echo 正在删除远程标签 v1.0.0...
git push origin :refs/tags/v1.0.0
echo ==============================

REM 检查标签是否删除成功
echo 检查标签 v1.0.0 是否删除成功...
git tag -l | findstr /I "v1.0.0" >nul
IF %ERRORLEVEL% EQU 0 (
    echo 远程标签 v1.0.0 删除失败，请手动检查。
) ELSE (
    echo 远程标签 v1.0.0 删除成功。
)
echo ==============================

REM 创建新标签
set /p tag_name=请输入新标签名（直接回车默认标签名为 v1.0.0）:
if "%tag_name%"=="" (
    set tag_name=v1.0.0
)
echo 正在创建新标签 %tag_name%，标签信息为 "为最新提交的重新创建标签"...
git tag -a %tag_name% -m "Recreate tags for the latest submission"
echo ==============================

REM 推送新标签到远程仓库
echo 正在将新的标签 %tag_name% 推送到远程仓库...
git push origin %tag_name%
echo ==============================

REM 检查标签是否推送成功
echo 检查标签 %tag_name% 是否推送成功...
git tag -l | findstr /I "%tag_name%" >nul
IF %ERRORLEVEL% EQU 0 (
    echo 标签 %tag_name% 推送成功。
) ELSE (
    echo 标签 %tag_name% 推送失败，请手动检查。
)
echo 当前仓库路径：%REPO_PATH%
echo ==============================
pause
goto MENU


echo ============= 五 、推送所有仓库更新 =================
:GIT_PUSH_ALL
cls
:: 设置要遍历的目录路径（可修改为你的目标路径）
set "target_dir=%~dp0"
echo 目标目录: %target_dir%

:: 遍历目标目录下的所有子目录
for /D %%i in ("%target_dir%\*") do (
    :: 检查是否是Git仓库
    if exist "%%i\.git" (
        echo ============================================
        echo 正在处理仓库: %%~nxi
        echo ============================================
        
        :: 进入仓库目录
        pushd "%%i"
        
        :: 执行Git操作
        git add .
        git commit -m "update"
        git pull --rebase
        git push
        
        :: 返回上级目录
        popd
        
        echo ============================================
        echo 仓库 %%~nxi 处理完成
        echo ============================================
        echo.
    ) else (
        echo 跳过非Git仓库: %%~nxi
    )
)

echo 所有有效Git仓库处理完毕
echo ============================================
pause
goto MENU 


echo ============= 六 、拉取所有仓库更新 =================
:GIT_UPDATE_ALL
cls
echo ============================================
echo      正在扫描目录及子目录中的 Git 仓库...
echo ============================================
for /d /r "." %%d in (.) do (
    if exist "%%d\.git" (
        echo.
        echo 检测到 Git 仓库: %%d
        cd /d "%%d"
        echo 正在拉取远程更新...
        git pull
        echo.
        echo 拉取完成: %%d
        echo ============================================
    )
)

echo 扫描完成！
pause
goto MENU 

echo ============= 七 、克隆所有仓库菜单 =================
:GIT_CLONE_ALL
@echo off
color 0A
setlocal enabledelayedexpansion

rem 定义仓库地址，每行一个
set "repo[1]=git@gitee.com:meimolihan/bat.git"  :: 常用批处理
set "repo[2]=git@gitee.com:meimolihan/360.git"  :: 360单机软件
set "repo[3]=git@gitee.com:meimolihan/final-shell.git"  :: 终端工具
set "repo[4]=git@gitee.com:meimolihan/clash.git"  :: 翻墙工具
set "repo[5]=git@gitee.com:meimolihan/dism.git"  :: Dism++系统优化工具
set "repo[6]=git@gitee.com:meimolihan/youtube.git"  :: youtube 视频下载
set "repo[7]=git@gitee.com:meimolihan/ffmpeg.git"  :: 音视频处理
set "repo[8]=git@gitee.com:meimolihan/bcuninstaller.git"  :: 卸载软件
set "repo[9]=git@gitee.com:meimolihan/typora.git"  :: 文本编辑器
set "repo[10]=git@gitee.com:meimolihan/lx-music-desktop.git"  :: 落雪音乐
set "repo[11]=git@gitee.com:meimolihan/xsnip.git"  :: 截图工具
set "repo[12]=git@gitee.com:meimolihan/image.git"  :: 图片处理
set "repo[13]=git@gitee.com:meimolihan/rename.git"  :: 大笨狗更名器
set "repo[14]=git@gitee.com:meimolihan/wallpaper.git"  :: windows 壁纸
set "repo[15]=git@gitee.com:meimolihan/trafficmonitor.git"  :: 显示网速

rem 获取仓库数量
set "repo_count=0"
for /l %%i in (1,1,999) do (
    if defined repo[%%i] (
        set /a repo_count+=1
    ) else (
        goto :break_loop
    )
)
:break_loop

:clone_menu
cls
echo ============================================================================
echo                              请选择要克隆的仓库
echo ============================================================================
for /l %%i in (1,1,!repo_count!) do (
    if defined repo[%%i] (
        rem 提取仓库名
        set "repo_url=!repo[%%i]!"
        for /f "tokens=2 delims=/" %%a in ("!repo_url:*.com:=!") do (
            set "repo_name=%%~na"
            echo %%i. 克隆仓库：!repo_name!
        )
    )
)
echo ============================================================================
echo x. 克隆所有仓库
echo y. 克隆新的仓库
echo ============================================================================
echo z. 返回到主菜单
echo 0. 退出
echo ============================================================================

set /p choice=请输入操作编号: 

rem 转换为小写以便不区分大小写比较
set "lc_choice=%choice%"
if "%choice%" neq "" (
    for /f "delims=" %%c in ('powershell -command "'%choice%'.ToLower()"') do (
        set "lc_choice=%%c"
    )
)

if "%lc_choice%"=="x" goto git_clone_all
if "%lc_choice%"=="y" goto git_clone_new
if "%lc_choice%"=="z" goto MENU
if "%lc_choice%"=="0" goto EXIT_SCRIPT

rem 检查数字选择
if %choice% geq 1 if %choice% leq !repo_count! (
    if defined repo[%choice%] (
        set "repo_url=!repo[%choice%]!"
        for /f "tokens=2 delims=/" %%a in ("!repo_url:*.com:=!") do (
            set "repo_name=%%~na"
            echo ============================================================================
            echo               正在克隆仓库：!repo_name!
            echo ============================================================================
            git clone !repo[%choice%]! || (
                echo [错误] 克隆仓库：!repo_name! 失败
            )
        )
        echo ============================================================================
        pause
        goto clone_menu
    )
)

echo 无效的选项，请重新输入。
echo ============================================================================
pause
goto clone_menu

:git_clone_all
echo 正在准备克隆所有仓库...
echo ================================================
set "all_success=1"

for /l %%i in (1,1,!repo_count!) do (
    if defined repo[%%i] (
        set "repo_url=!repo[%%i]!"
        for /f "tokens=2 delims=/" %%a in ("!repo_url:*.com:=!") do (
            set "repo_name=%%~na"
            echo 正在克隆仓库：!repo_name!
            git clone !repo[%%i]! || (
                echo [错误] 克隆仓库：!repo_name! 失败
                set "all_success=0"
            )
            echo ================================================
        )
    )
)

if !all_success! equ 1 (
    echo 所有仓库克隆成功！
) else (
    echo 部分仓库克隆失败，请检查网络或仓库地址。
)

echo ================================================
pause
goto clone_menu

:git_clone_new
cls
echo ============================================
echo                 Git 克隆仓库
echo ============================================
set /p repoUrl="请输入Git仓库的URL或git clone命令: "

if "%repoUrl%"=="" (
    echo 未输入有效的URL，请重新运行脚本并输入正确的URL。
    pause
    goto clone_menu
)

set "cleanUrl=%repoUrl%"
set "cleanUrl=%cleanUrl:git clone =%"
set "cleanUrl=%cleanUrl:git clone=%"

echo 正在克隆仓库，请稍候...
git clone %cleanUrl%

if %errorlevel% neq 0 (
    echo ============================================
    echo 克隆失败，请检查URL是否正确或网络连接。
    echo ============================================
) else (
    echo ============================================
    echo 克隆成功！
    echo ============================================
)
pause
goto clone_menu


echo ============================================
:EXIT_SCRIPT
cls
echo.
echo.
echo ==============================
echo         感谢使用，再见！
echo ==============================
timeout /t 2 >nul
exit