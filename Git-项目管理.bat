@echo off
color 0A

:MENU
color 0A
cls
echo ==============================
echo         Git ��Ŀ����ű�
echo ==============================
echo 1. ���Git�ֿ�״̬
echo 2. �ύ�����͸���
echo 3. ��ȡԶ�̸���
echo ==============================
echo 0. �˳�
echo ==============================
    set "choice="
    set /p choice="������������ (0 - 3): "
    if not defined choice (
        echo ���벻��Ϊ�գ������루0 - 3��֮������֡�
        timeout /t 2 >nul
		rem ����Ҫ���صĲ˵�
        goto menu
    )

if "%choice%"=="1" goto CHECK_STATUS
if "%choice%"=="2" goto COMMIT_PUSH
if "%choice%"=="3" goto PULL_UPDATE
if "%choice%"=="0" goto EXIT_SCRIPT

echo ��Чѡ�������ѡ��...
pause
goto MENU

:CHECK_STATUS
echo ���ڼ��Git�ֿ�״̬...
git status
echo �����ɣ��������ʾȷ���ļ�״̬��
pause
goto MENU

:COMMIT_PUSH
echo �ύ�����͸��ģ�
set /p commit_msg=�������ύ��Ϣ��ֱ�ӻس�Ĭ��Ϊ "update"���� 
if "%commit_msg%"=="" set commit_msg=update

echo ����������и��ĵ��ݴ���...
git add .
echo �����ɣ�

echo �����ύ���ģ��ύ��ϢΪ��%commit_msg%
git commit -m "%commit_msg%"
echo �ύ��ɣ�

echo �������͸��ĵ�Զ�ֿ̲�...
git push
echo ������ɣ����ĸ����ѳɹ�ͬ����Զ�ֿ̲⡣

pause
goto MENU

:PULL_UPDATE
echo ���ڴ�Զ�ֿ̲���ȡ����...
git pull
if %errorlevel% equ 0 (
    echo ��ȡ�ɹ������زֿ��������°汾��
) else (
    echo ��ȡʧ�ܣ����������Զ�ֿ̲��ַ�Ƿ���ȷ��
)
pause
goto MENU

:EXIT_SCRIPT
echo �ű����˳�����лʹ�ã�
exit