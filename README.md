# WindowsApps-Replace
Windows Applications can't be launched ? Like Windows Terminal, Microsoft Store or the notepad ? Use WAR !

You just need to launch a PowerShell and install PSExec (https://www.youtube.com/watch?v=G7VP9h-v9Sg) and execute this command in an administrator Powershell : 

` psexec.exe -i -s powershell -ExecutionPolicy Bypass -File "C:\Users\amisa\Downloads\WindowsAppsUnfukker-main\WindowsAppsUnfukker-main\WindowsAppsUnfukker.ps1"`

![image](https://user-images.githubusercontent.com/82168053/169689410-b4b27d2e-be1a-48cf-90e2-59c2274b88cc.png)
![image](https://user-images.githubusercontent.com/82168053/169689601-38a67050-eae8-4300-bac4-e21a393c13ea.png)

