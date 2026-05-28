# One-line setup
$w="C:\Program Files\UltraVNC";cd $w;.\winvnc.exe -service;.\winvnc.exe -storepassword "123456";netsh advfirewall firewall add rule name="UltraVNC" dir=in action=allow protocol=TCP localport=5900
