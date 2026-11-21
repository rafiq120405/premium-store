@echo off
title PremiumHub Local Server
echo ==============================================
echo Menjalankan Server Toko PremiumHub di Port 3000...
echo ==============================================
start http://localhost:3000
node server.js
pause
