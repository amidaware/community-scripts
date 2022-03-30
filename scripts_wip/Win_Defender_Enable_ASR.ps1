# Before enabling, you should test with Auditmode
# https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/attack-surface-reduction?view=o365-worldwide


#Block abuse of exploited vulnerable signed drivers     
Set-MpPreference -AttackSurfaceReductionRules_Ids "56a863a9-875e-4185-98a7-b882c64b5ce5" -AttackSurfaceReductionRules_Actions Enabled
#Block executable content from email client and webmail
Set-MpPreference -AttackSurfaceReductionRules_Ids "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" -AttackSurfaceReductionRules_Actions Enabled
#Block all Office applications from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" -AttackSurfaceReductionRules_Actions Enabled
#Block Office applications from creating executable content
Add-MpPreference -AttackSurfaceReductionRules_Ids "3B576869-A4EC-4529-8536-B80A7769E899" -AttackSurfaceReductionRules_Actions Enabled
#Block Office applications from injecting code into other processes
Add-MpPreference -AttackSurfaceReductionRules_Ids "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" -AttackSurfaceReductionRules_Actions Enabled
#Block JavaScript or VBScript from launching downloaded executable content
Add-MpPreference -AttackSurfaceReductionRules_Ids "D3E037E1-3EB8-44C8-A917-57927947596D" -AttackSurfaceReductionRules_Actions Enabled
#Block execution of potentially obfuscated scripts
Add-MpPreference -AttackSurfaceReductionRules_Ids "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" -AttackSurfaceReductionRules_Actions Enabled
#Block Win32 API calls from Office macros
Add-MpPreference -AttackSurfaceReductionRules_Ids "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" -AttackSurfaceReductionRules_Actions Enabled
#Block executable files from running unless they meet a prevalence, age, or trusted list criterion
Add-MpPreference -AttackSurfaceReductionRules_Ids "01443614-cd74-433a-b99e-2ecdc07bfc25" -AttackSurfaceReductionRules_Actions Enabled
#Use advanced protection against ransomware
Add-MpPreference -AttackSurfaceReductionRules_Ids "c1db55ab-c21a-4637-bb3f-a12568109d35" -AttackSurfaceReductionRules_Actions Enabled
#Block credential stealing from the Windows local security authority subsystem (lsass.exe)
Add-MpPreference -AttackSurfaceReductionRules_Ids "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" -AttackSurfaceReductionRules_Actions Disabled
#Block process creations originating from PSExec and WMI commands
Add-MpPreference -AttackSurfaceReductionRules_Ids "d1e49aac-8f56-4280-b9ba-993a6d77406c" -AttackSurfaceReductionRules_Actions Enabled
#Block untrusted and unsigned processes that run from USB
Add-MpPreference -AttackSurfaceReductionRules_Ids "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" -AttackSurfaceReductionRules_Actions Enabled
#Block Office communication application from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids "26190899-1602-49e8-8b27-eb1d0a1ce869" -AttackSurfaceReductionRules_Actions Disabled
#Block Adobe Reader from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" -AttackSurfaceReductionRules_Actions Enabled
#Block persistence through WMI event subscription
Add-MpPreference -AttackSurfaceReductionRules_Ids "e6db77e5-3df2-4cf1-b95a-636979351e5b" -AttackSurfaceReductionRules_Actions Enabled`