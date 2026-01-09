    function Write-Host {
        param($Object, $BackgroundColor, $ForegroundColor, $NoNewline)
        
        # Se o arquivo de log já foi definido, escreve direto nele
        if ($script:LogFile) {
            try {
                # Adiciona Data/Hora
                $Time = Get-Date -Format "HH:mm:ss"
                Add-Content -Path $script:LogFile -Value "[$Time] $Object" -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    
    # auto elevação de privilégios
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        try {
            # Relança o próprio script pedindo permissão de Admin
            $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
            $newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"";
            $newProcess.Verb = "runas";
            [System.Diagnostics.Process]::Start($newProcess);
            exit;
        } catch {
            # Se o usuario clicar em "Nao" no UAC
            Write-Warning "A permissão de administrador é necessária."
            exit
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if ($PSScriptRoot) {
        $BaseDir = $PSScriptRoot
    } else {
        $BaseDir = [System.AppDomain]::CurrentDomain.BaseDirectory
    }

    $script:LogFile = Join-Path $BaseDir "Install_Log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"

    try {
            New-Item -Path $script:LogFile -ItemType File -Force | Out-Null
            Write-Host "Iniciando configurador. Log criado em: $script:LogFile"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Não foi possível criar o arquivo de Log na pasta: $BaseDir`nVerifique permissões.", "Erro de Log", "OK", "Warning")
        }

        Write-Host "Iniciando configurador..."

    #cores
    $Theme = @{
        Background     = [System.Drawing.ColorTranslator]::FromHtml("#F9F9F9")
        Header         = [System.Drawing.ColorTranslator]::FromHtml("#2C3E50")
        HeaderTx       = [System.Drawing.ColorTranslator]::FromHtml("#ECF0F1")
        TextMain       = [System.Drawing.ColorTranslator]::FromHtml("#34495E")
        TextDim        = [System.Drawing.ColorTranslator]::FromHtml("#7F8C8D")
        Accent         = [System.Drawing.ColorTranslator]::FromHtml("#2980B9")
        ButtonSuccess  = [System.Drawing.ColorTranslator]::FromHtml("#27AE60")
        ButtonSuccessHov = [System.Drawing.ColorTranslator]::FromHtml("#2ECC71")
        ButtonCancel   = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
        ButtonCancelHov = [System.Drawing.ColorTranslator]::FromHtml("#D5D8DC")
        SelectedBG     = [System.Drawing.ColorTranslator]::FromHtml("#EBF5FB")
        SelectedBorder = [System.Drawing.ColorTranslator]::FromHtml("#3498DB")
        InactiveBorder = [System.Drawing.ColorTranslator]::FromHtml("#D5D8DC")
    }

    # fontes
    $FontTitle = New-Object System.Drawing.Font("Segoe UI", 12)
    $FontLabel = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $FontBody  = New-Object System.Drawing.Font("Segoe UI", 10)
    $FontSmall = New-Object System.Drawing.Font("Segoe UI", 9)

    # helper para bordas quadradas
    function Set-SquareBorder {
        param(
            [System.Windows.Forms.Control]$Control,
            [System.Drawing.Color]$Color,
            [int]$Width = 1
        )

        # Remove pintura anterior para nao acumular eventos
        if ($Control.Tag -is [System.Management.Automation.ScriptBlock]) {
            $Control.Remove_Paint($Control.Tag)
        }

        $PaintAction = {
            $ctrl = $args[0]
            $e    = $args[1] # PaintEventArgs
            $g = $e.Graphics
            $pen = New-Object System.Drawing.Pen($Color, $Width)
            [int]$w = $ctrl.ClientSize.Width - 1
            [int]$h = $ctrl.ClientSize.Height - 1
            $g.DrawRectangle($pen, 0, 0, $w, $h)
            $pen.Dispose()
        }.GetNewClosure()

        $Control.Tag = $PaintAction
        $Control.Add_Paint($PaintAction)
        $Control.Invalidate()
    }

    # janela principal
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Assistente de Configurador de Ambiente"
    $Form.Size = New-Object System.Drawing.Size(600, 540)
    $Form.StartPosition = "CenterScreen"
    $Form.FormBorderStyle = "None"
    $Form.BackColor = $Theme.Background

    try {
        $CurrentExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($CurrentExe)
    } catch {}

    # Borda externa
    Set-SquareBorder $Form ([System.Drawing.Color]::Gray) 1

    # header
    $Header = New-Object System.Windows.Forms.Panel
    $Header.Size = New-Object System.Drawing.Size(600, 60)
    $Header.Location = New-Object System.Drawing.Point(0, 0)
    $Header.BackColor = $Theme.Header
    $Form.Controls.Add($Header)

    $LblTitle = New-Object System.Windows.Forms.Label
    $LblTitle.Text = "VERIFICADOR DE REGISTROS DO FORPONTO"
    $LblTitle.Font = $FontTitle
    $LblTitle.ForeColor = $Theme.HeaderTx
    $LblTitle.AutoSize = $false
    $LblTitle.Dock = "Fill"
    $LblTitle.TextAlign = "MiddleCenter"
    $Header.Controls.Add($LblTitle)

    # arrastar janela
    $script:isDrag = $false
    $script:startPt = [System.Drawing.Point]::Empty

    $MouseDown = {
        if ($_.Button -eq 'Left') {
            $script:isDrag = $true
            $script:startPt = $_.Location
        }
    }

    $MouseMove = {
        if ($script:isDrag) {
            $pos = [System.Windows.Forms.Cursor]::Position
            $Form.Location = New-Object System.Drawing.Point(($pos.X - $script:startPt.X), ($pos.Y - $script:startPt.Y))
        }
    }

    $MouseUp = { $script:isDrag = $false }

    $Header.Add_MouseDown($MouseDown)
    $Header.Add_MouseMove($MouseMove)
    $Header.Add_MouseUp($MouseUp)

    $LblTitle.Add_MouseDown($MouseDown)
    $LblTitle.Add_MouseMove($MouseMove)
    $LblTitle.Add_MouseUp($MouseUp)

    # content
    $Panel = New-Object System.Windows.Forms.Panel
    $Panel.Location = New-Object System.Drawing.Point(30, 80)
    $Panel.Size = New-Object System.Drawing.Size(540, 440)
    $Form.Controls.Add($Panel)

    # descrição
    $LblIntro = New-Object System.Windows.Forms.Label
    $LblIntro.Text = "Ferramenta de ajuste automático de compatibilidade e otimização do BDE para o sistema Forponto."
    $LblIntro.Font = $FontBody
    $LblIntro.ForeColor = $Theme.TextMain
    $LblIntro.Size = New-Object System.Drawing.Size(540, 45)
    $Panel.Controls.Add($LblIntro)

    # diretorio BDE
    $LblStep1 = New-Object System.Windows.Forms.Label
    $LblStep1.Text = "DIRETÓRIO DE INSTALAÇÃO DO BDE"
    $LblStep1.Font = $FontLabel
    $LblStep1.ForeColor = $Theme.Accent
    $LblStep1.Location = New-Object System.Drawing.Point(0, 40)
    $LblStep1.Size = New-Object System.Drawing.Size(540, 25)
    $LblStep1.TextAlign = "MiddleCenter"
    $Panel.Controls.Add($LblStep1)

    $btnWidth = 45
    $gap = 5
    $inputWidth = 540 - $btnWidth - $gap

    $PathContainer = New-Object System.Windows.Forms.Panel
    $PathContainer.Location = New-Object System.Drawing.Point(0, 65)
    $PathContainer.Size = New-Object System.Drawing.Size($inputWidth, 32)
    $PathContainer.BackColor = "White"
    Set-SquareBorder $PathContainer $Theme.InactiveBorder 1
    $Panel.Controls.Add($PathContainer)

    $TxtPath = New-Object System.Windows.Forms.TextBox
    $TxtPath.BorderStyle = "None"
    $TxtPath.Location = New-Object System.Drawing.Point(8, 7)
    $TxtPath.Width = $inputWidth - 16
    $TxtPath.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $TxtPath.ForeColor = $Theme.TextMain
    $PathContainer.Controls.Add($TxtPath)

    # auto-deteccao do BDE
    $Paths = @("C:\Program Files (x86)\Borland\Common Files\BDE", "C:\Forponto\BDE", "D:\Forponto\BDE")
    foreach ($p in $Paths) { if (Test-Path "$p\IDAPI32.DLL") { $TxtPath.Text = $p; break } }

    # botao browse
    $BtnBrowse = New-Object System.Windows.Forms.Button
    $BtnBrowse.Text = [System.Char]::ConvertFromUtf32(0x1F4C2)
    $BtnBrowse.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 12)
    $BtnBrowse.Location = New-Object System.Drawing.Point(($inputWidth + $gap), 65)
    $BtnBrowse.Size = New-Object System.Drawing.Size($btnWidth, 32)
    $BtnBrowse.FlatStyle = "Flat"
    $BtnBrowse.BackColor = "#E0E0E0"
    $BtnBrowse.ForeColor = "#333333"
    $BtnBrowse.FlatAppearance.BorderSize = 0
    $BtnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Panel.Controls.Add($BtnBrowse)

    $BtnBrowse.Add_Click({
        $Diag = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($Diag.ShowDialog() -eq "OK") { $TxtPath.Text = $Diag.SelectedPath }
    })

    $BtnBrowse.Add_MouseEnter({ $this.BackColor = "#D5D8DC" })
    $BtnBrowse.Add_MouseLeave({ $this.BackColor = "#E0E0E0" })

    # diretorio do forponto
    $LblStepFp = New-Object System.Windows.Forms.Label
    $LblStepFp.Text = "DIRETÓRIO DE INSTALAÇÃO DO FORPONTO"
    $LblStepFp.Font = $FontLabel; $LblStepFp.ForeColor = $Theme.Accent
    $LblStepFp.Location = New-Object System.Drawing.Point(0, 115)
    $LblStepFp.Size = New-Object System.Drawing.Size(540, 20)
    $LblStepFp.TextAlign = "MiddleCenter"
    $Panel.Controls.Add($LblStepFp)

    $FpContainer = New-Object System.Windows.Forms.Panel
    $FpContainer.Location = New-Object System.Drawing.Point(0, 135)
    $FpContainer.Size = New-Object System.Drawing.Size($inputWidth, 32)
    $FpContainer.BackColor = "White"
    Set-SquareBorder $FpContainer $Theme.InactiveBorder 1
    $Panel.Controls.Add($FpContainer)
    $TxtFpPath = New-Object System.Windows.Forms.TextBox
    $TxtFpPath.BorderStyle = "None"; $TxtFpPath.Location = New-Object System.Drawing.Point(8, 7)
    $TxtFpPath.Width = $inputWidth - 16; $TxtFpPath.Font = $FontBody; $TxtFpPath.ForeColor = $Theme.TextMain
    $FpContainer.Controls.Add($TxtFpPath)

    # auto-deteccao do Forponto
    $FpPaths = @("A:\Forponto", "B:\Forponto", "C:\Forponto", "D:\Forponto", "E:\Forponto", "F:\Forponto", "G:\Forponto", "H:\Forponto", "I:\Forponto", "J:\Forponto", "K:\Forponto", "L:\Forponto", "M:\Forponto", "N:\Forponto", "O:\Forponto", "P:\Forponto", "Q:\Forponto", "R:\Forponto", "S:\Forponto", "T:\Forponto", "U:\Forponto", "V:\Forponto", "W:\Forponto", "X:\Forponto", "Y:\Forponto", "Z:\Forponto", "C:\Program Files (x86)\Forponto", "C:\Program Files\Forponto")
    foreach ($p in $FpPaths) { if (Test-Path $p) { $TxtFpPath.Text = $p; break } }

    $BtnBrowseFp = New-Object System.Windows.Forms.Button
    $BtnBrowseFp.Text = [System.Char]::ConvertFromUtf32(0x1F4C2)
    $BtnBrowseFp.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 12)
    $BtnBrowseFp.Location = New-Object System.Drawing.Point(($inputWidth + $gap), 135)
    $BtnBrowseFp.Size = New-Object System.Drawing.Size($btnWidth, 32)
    $BtnBrowseFp.FlatStyle = "Flat"; $BtnBrowseFp.BackColor = "#E0E0E0"; $BtnBrowseFp.FlatAppearance.BorderSize = 0
    $BtnBrowseFp.Cursor = [System.Windows.Forms.Cursors]::Hand

    $BtnBrowseFp.Add_Click({
        $Diag = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($Diag.ShowDialog() -eq "OK") { $TxtFpPath.Text = $Diag.SelectedPath }
    })
    $BtnBrowseFp.Add_MouseEnter({ $this.BackColor = "#D5D8DC" })
    $BtnBrowseFp.Add_MouseLeave({ $this.BackColor = "#E0E0E0" })

    $Panel.Controls.Add($BtnBrowseFp)

    # perfil de uso
    $LblStep2 = New-Object System.Windows.Forms.Label
    $LblStep2.Text = "PERFIL DE USO"
    $LblStep2.Font = $FontLabel
    $LblStep2.ForeColor = $Theme.Accent
    $LblStep2.Location = New-Object System.Drawing.Point(0, 180)
    $LblStep2.Size = New-Object System.Drawing.Size(540, 25)
    $LblStep2.TextAlign = "MiddleCenter"
    $Panel.Controls.Add($LblStep2)

    $BoxOpts = New-Object System.Windows.Forms.Panel
    $BoxOpts.Location = New-Object System.Drawing.Point(0, 205)
    $BoxOpts.Size = New-Object System.Drawing.Size(540, 180)
    $BoxOpts.BackColor = $Theme.Background
    $Panel.Controls.Add($BoxOpts)

    # perfil dedicado
    $PnlDed = New-Object System.Windows.Forms.Panel
    $PnlDed.Location = New-Object System.Drawing.Point(0, 0)
    $PnlDed.Size = New-Object System.Drawing.Size(540, 80)
    $PnlDed.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BoxOpts.Controls.Add($PnlDed)
    $RadDed = New-Object System.Windows.Forms.RadioButton; $RadDed.Visible=$false; $RadDed.Checked=$true
    $PnlDed.Controls.Add($RadDed)

    $LblDedTitle = New-Object System.Windows.Forms.Label
    $LblDedTitle.Text = "Modo Exclusivo (Recomendado)"
    $LblDedTitle.Font = $FontLabel; $LblDedTitle.ForeColor = $Theme.TextMain
    $LblDedTitle.Location = New-Object System.Drawing.Point(15, 10); $LblDedTitle.Size = New-Object System.Drawing.Size(500, 25)
    $PnlDed.Controls.Add($LblDedTitle)

    $LblDedDesc = New-Object System.Windows.Forms.Label
    $LblDedDesc.Text = "Aplica correções críticas de memória (ASLR) e otimiza a performance.`nIdeal para servidores ou estações exclusivas do Forponto."
    $LblDedDesc.Font = $FontSmall; $LblDedDesc.ForeColor = $Theme.TextDim
    $LblDedDesc.Location = New-Object System.Drawing.Point(15, 35); $LblDedDesc.Size = New-Object System.Drawing.Size(500, 40)
    $PnlDed.Controls.Add($LblDedDesc)

    # perfil compartilhado
    $PnlShared = New-Object System.Windows.Forms.Panel
    $PnlShared.Location = New-Object System.Drawing.Point(0, 90)
    $PnlShared.Size = New-Object System.Drawing.Size(540, 80)
    $PnlShared.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BoxOpts.Controls.Add($PnlShared)
    $RadShared = New-Object System.Windows.Forms.RadioButton; $RadShared.Visible=$false
    $PnlShared.Controls.Add($RadShared)

    $LblSharedTitle = New-Object System.Windows.Forms.Label
    $LblSharedTitle.Text = "Modo de Compatibilidade"
    $LblSharedTitle.Font = $FontLabel; $LblSharedTitle.ForeColor = $Theme.TextMain
    $LblSharedTitle.Location = New-Object System.Drawing.Point(15, 10); $LblSharedTitle.Size = New-Object System.Drawing.Size(500, 25)
    $PnlShared.Controls.Add($LblSharedTitle)
    $LblSharedDesc = New-Object System.Windows.Forms.Label
    $LblSharedDesc.Text = "Mantém configurações padrão.`nUse caso outros programas utilizem o BDE nesta máquina."
    $LblSharedDesc.Font = $FontSmall; $LblSharedDesc.ForeColor = $Theme.TextDim
    $LblSharedDesc.Location = New-Object System.Drawing.Point(15, 35); $LblSharedDesc.Size = New-Object System.Drawing.Size(500, 40)
    $PnlShared.Controls.Add($LblSharedDesc)

    # logica de selecao
    function Update-CardSelection {
        if ($RadDed.Checked) {
            $PnlDed.BackColor = $Theme.SelectedBG
            Set-SquareBorder $PnlDed $Theme.SelectedBorder 2
            $PnlShared.BackColor = [System.Drawing.Color]::White
            Set-SquareBorder $PnlShared $Theme.InactiveBorder 1
        } else {
            $PnlDed.BackColor = [System.Drawing.Color]::White
            Set-SquareBorder $PnlDed $Theme.InactiveBorder 1
            $PnlShared.BackColor = $Theme.SelectedBG
            Set-SquareBorder $PnlShared $Theme.SelectedBorder 2

        }

    }

    $ActionSelectDed = { $RadDed.Checked = $true; $RadShared.Checked = $false; Update-CardSelection }
    $ActionSelectShared = { $RadShared.Checked = $true; $RadDed.Checked = $false; Update-CardSelection }

    $PnlDed.Add_Click($ActionSelectDed); $LblDedTitle.Add_Click($ActionSelectDed); $LblDedDesc.Add_Click($ActionSelectDed)

    $PnlShared.Add_Click($ActionSelectShared); $LblSharedTitle.Add_Click($ActionSelectShared); $LblSharedDesc.Add_Click($ActionSelectShared)

    Update-CardSelection

    # botoes finais

    # Cancelar
    $BtnCancel = New-Object System.Windows.Forms.Button
    $BtnCancel.Text = "Cancelar"
    $BtnCancel.Font = $FontBody
    $BtnCancel.Size = New-Object System.Drawing.Size(100, 40)
    $BtnCancel.Location = New-Object System.Drawing.Point(0, 400) # <-- Mudou para 0
    $BtnCancel.FlatStyle = "Flat"
    $BtnCancel.FlatAppearance.BorderSize = 0
    $BtnCancel.BackColor = $Theme.ButtonCancel
    $BtnCancel.ForeColor = $Theme.TextMain
    $BtnCancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnCancel.Add_Click({ $Form.Close() })
    $BtnCancel.Add_MouseEnter({ $this.BackColor = $Theme.ButtonCancelHov })
    $BtnCancel.Add_MouseLeave({ $this.BackColor = $Theme.ButtonCancel })
    $Panel.Controls.Add($BtnCancel)

    # Executar
    $BtnGo = New-Object System.Windows.Forms.Button
    $BtnGo.Text = "Executar"
    $BtnGo.Font = $FontLabel
    $BtnGo.Size = New-Object System.Drawing.Size(100, 40)
    $BtnGo.Location = New-Object System.Drawing.Point(440, 400) # <-- Mudou para 440
    $BtnGo.FlatStyle = "Flat"
    $BtnGo.FlatAppearance.BorderSize = 0
    $BtnGo.BackColor = $Theme.ButtonSuccess
    $BtnGo.ForeColor = "White"
    $BtnGo.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnGo.Add_MouseEnter({ $this.BackColor = $Theme.ButtonSuccessHov })
    $BtnGo.Add_MouseLeave({ $this.BackColor = $Theme.ButtonSuccess })
    $Panel.Controls.Add($BtnGo)

    # logica do programa
    $BtnGo.Add_Click({

    # validação do BDE
    $Path = $TxtPath.Text.Trim('"').Trim()

    # arquivos essenciais do BDE
    $CriticalFilesBDE = @("IDAPI32.DLL",  "BLW32.DLL", "BANTAM.DLL", "BDEADMIN.EXE", "IDR20009.DLL", "IDSQL32.DLL", "IDPDX32.DLL", "IDDBAS32.DLL")
    $MissingFilesBDE = @()

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) {
        [System.Windows.Forms.MessageBox]::Show("O diretório informado nao existe.", "Erro", "OK", "Error")
        return
    }

    foreach ($file in $CriticalFilesBDE) {
        $found = Get-ChildItem -Path $Path -Filter $file -Recurse -ErrorAction SilentlyContinue
        if (!$found) { $MissingFilesBDE += $file }
    }

    if ($MissingFilesBDE.Count -gt 0) {
        $msg = "A instalação do BDE neste diretório parece incompleta.`n`nArquivos ausentes:`n" + ($MissingFilesBDE -join "`n") + "`n`nDeseja tentar configurar mesmo assim? (não recomendado)"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Instalação Corrompida", "YesNo", "Warning") 
        if ($result -eq "No") { return }
    }

    # arquivos essenciais do Forponto
    $CriticalFilesFP = @("Forponto.exe", "libeay32.dll", "ssleay32.dll", "TaskRecursosCompartilhados.dll", "Forponto.inf")
    $MissingFilesFP  = @()

    # validação do Forponto
    $FpPath = $TxtFpPath.Text.Trim('"').Trim()

    $CriticalFilesFP = @("Forponto.exe", "libeay32.dll", "ssleay32.dll", "TaskRecursosCompartilhados.dll")
    $MissingFilesFP  = @()

    if ([string]::IsNullOrWhiteSpace($FpPath) -or !(Test-Path $FpPath)) {
        [System.Windows.Forms.MessageBox]::Show("O diretório do Forponto não foi informado ou não existe.", "Erro", "OK", "Error")
        return
    }

    # tenta localizar o executavel principal para ajustar o caminho
    $MainExe = Get-ChildItem -Path $FpPath -Filter "Forponto.exe" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($MainExe) {
        $FpPath = $MainExe.DirectoryName
        $TxtFpPath.Text = $FpPath
    }

    # raiz do Forponto
    foreach ($file in $CriticalFilesFP) {
        if (!(Test-Path "$FpPath\$file")) {
            $MissingFilesFP += $file
        }
    }

    # dados do Forponto
    if (!(Test-Path "$FpPath\Dados")) { 
        $MissingFilesFP += "Pasta 'Dados'" 
    } elseif (!(Test-Path "$FpPath\Dados\Forponto.inf")) {
        $MissingFilesFP += "Dados\Forponto.inf" 
    }

    if ($MissingFilesFP.Count -gt 0) {
        $msg = "A estrutura do Forponto em '$FpPath' está incompleta.`n`nAusentes:`n" + ($MissingFilesFP -join "`n") + "`n`nDeseja continuar assim mesmo?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Aviso de Integridade", "YesNo", "Warning") 
        if ($result -eq "No") { return }
    }

    # checa privilégios de admin
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.Forms.MessageBox]::Show("Execute como Administrador para alterar o Registro.", "Permissão", "OK", "Warning"); return
    }

    $BtnGo.Text = "Processando..."
    $BtnGo.Enabled = $false
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $Form.Refresh()

    try {
    #ponto de restauração
        try {
            $SysRestore = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
            if ($SysRestore -ne $null) {
                Write-Host "Verificando Ponto de Restauraçao." -ForegroundColor Cyan
                
                # Tenta criar. Se falhar (ex: limite de 24h), vai para o catch sem travar a tela
                Checkpoint-Computer -Description "Backup Pre-Forponto" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop SilentlyContinue
                
                Write-Host "Ponto de Restauracao criado com sucesso." -ForegroundColor Green
            }
        } catch { 
            # Se der erro (ex: já existe um backup hoje), registra no log, sem janela de alerta
            Write-Host "Aviso: Ponto de restauracao ignorado (Limite de frequencia ou servico inativo)." -ForegroundColor Yellow
            Write-Host "Seguindo para backup do registro..." -ForegroundColor DarkGray
        }

        # backup do registro do BDE usando o reg.exe
        $RegTarget = "HKLM\SOFTWARE\WOW6432Node\Borland"
        $BackupRegFile = Join-Path $BaseDir "Backup_Borland_$(Get-Date -Format 'yyyyMMdd_HHmm').reg"

        if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Borland") {
            Write-Host "Exportando configurao atual do BDE para: $BackupRegFile" -ForegroundColor Cyan
            
            $proc = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$RegTarget`" `"$BackupRegFile`" /y" -Wait -PassThru -NoNewWindow
            
            if ($proc.ExitCode -eq 0) {
                Write-Host "Backup de registro salvo." -ForegroundColor Green
            }
        }

        #mapeamento de chaves e valores
        $RegBase = "HKLM:\SOFTWARE\WOW6432Node\Borland"
        $DefaultBdePath = "C:\Program Files (x86)\Borland\Common Files\BDE"

        function Get-BtlPath {
            param([string]$FileName)
            if (Test-Path "$Path\$FileName") { return "$Path\$FileName" }
            return "$DefaultBdePath\$FileName"
        }

        $RegistryMap = @{
            "BLW32" = @{
                "BLAPIPATH"   = "$Path\"
                "LOCALE_LIB1" = Get-BtlPath "USA.BTL"
                "LOCALE_LIB2" = Get-BtlPath "EUROPE.BTL"
                "LOCALE_LIB3" = Get-BtlPath "OTHER.BTL"
                "LOCALE_LIB4" = Get-BtlPath "CHARSET.BTL"
                "LOCALE_LIB5" = Get-BtlPath "CEEUROPE.BTL"
                "LOCALE_LIB6" = Get-BtlPath "FAREAST.BTL"
                "LOCALE_LIB7" = Get-BtlPath "JAPAN.BTL"
            }

            "Database Engine" = @{
                "DLLPATH"      = "$Path\"
                "CONFIGFILE01" = "$Path\IDAPI32.CFG"
                "RESOURCE"     = "0009"
            }

            "Database Engine\Settings\DRIVERS\DB2\DB OPEN" = @{
                "USER NAME"="MYNAME"
                "DB2 DSN"="DB2_SERVER"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "LANGDRIVER"=""
                "SQLQRYMODE"=""
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "SCHEMA CACHE TIME"="-1"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "ENABLE BCD"="FALSE"
                "ROWSET SIZE"="20"
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
            }

            "Database Engine\Settings\DRIVERS\DB2\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLDB232.DLL"
                "DRIVER"="IBM DB2 DRIVER"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
            }

            "Database Engine\Settings\DRIVERS\DBASE\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="FILE"
                "LANGDRIVER"="DBWINWE0"
            }

            "Database Engine\Settings\DRIVERS\DBASE\TABLE CREATE" = @{
                "LEVEL"="7"
                "MDX BLOCK SIZE"="1024"
                "MEMO FILE BLOCK SIZE"="1024"
            }
   
            "Database Engine\Settings\DRIVERS\FOXPRO\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="FILE"
                "LANGDRIVER"="DBWINUS0"
            }

            "Database Engine\Settings\DRIVERS\FOXPRO\TABLE CREATE" = @{
                "LEVEL"="25"
            }

            "Database Engine\Settings\DRIVERS\INFORMIX\DB OPEN" = @{
                "SERVER NAME"="INF_SERVER"
                "DATABASE NAME"="MY_DATABASE"
                "USER NAME"="MYNAME"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "LANGDRIVER"=""
                "SQLQRYMODE"="SERVER"
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "LOCK MODE"="5"
                "DATE MODE"="1"
                "DATE SEPARATOR"="/"
                "SCHEMA CACHE TIME"="-1"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "ENABLE BCD"="FALSE"
                "LIST SYNONYMS"="NONE"
                "DBNLS"=""
                "COLLCHAR"=""
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
            }

            "Database Engine\Settings\DRIVERS\INFORMIX\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLINF32.DLL"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
            }

            "Database Engine\Settings\DRIVERS\INTRBASE\DB OPEN" = @{
                "SERVER NAME"="IB_SERVER:/PATH/DATABASE.GDB"
                "USER NAME"="MYNAME"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "LANGDRIVER"=""
                "SQLQRYMODE"=""
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "SCHEMA CACHE TIME"="-1"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "ENABLE BCD"="FALSE"
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
            }

            "Database Engine\Settings\DRIVERS\INTRBASE\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLINT32.DLL"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
            }

            "Database Engine\Settings\DRIVERS\MSACCESS\DB OPEN" = @{
                "DATABASE NAME"="DRIVE:/PATH/DATABASE.MDB"
                "USER NAME"=""
                "OPEN MODE"="READ/WRITE"
                "LANGDRIVER"=""
                "SYSTEM DATABASE"=""
            }

            "Database Engine\Settings\DRIVERS\MSACCESS\INIT" = @{
                "VERSION"="1.0"
                "TYPE"="SERVER"
                "DLL32"="IDDAO32.DLL"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
            }

            "Database Engine\Settings\DRIVERS\MSSQL\DB OPEN" = @{
                "DATABASE NAME"=""
                "SERVER NAME"="MSS_SERVER"
                "USER NAME"="MYNAME"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "BLOB EDIT LOGGING"=""
                "LANGDRIVER"=""
                "SQLQRYMODE"=""
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "DATE MODE"="0"
                "SCHEMA CACHE TIME"="-1"
                "MAX QUERY TIME"="300"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "HOST NAME"=""
                "APPLICATION NAME"=""
                "NATIONAL LANG NAME"=""
                "ENABLE BCD"="FALSE"
                "TDS PACKET SIZE"="4096"
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
            }

            "Database Engine\Settings\DRIVERS\MSSQL\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLMSS32.DLL"
                "VENDOR INIT"=""
                "CONNECT TIMEOUT"="60"
                "TIMEOUT"="300"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
                "MAX DBPROCESSES"="31"
            }

            "Database Engine\Settings\DRIVERS\ORACLE\DB OPEN" = @{
                "SERVER NAME"="ORA_SERVER"
                "USER NAME"="MYNAME"
                "NET PROTOCOL"="TNS"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "LANGDRIVER"=""
                "SQLQRYMODE"="SERVER"
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "SCHEMA CACHE TIME"="-1"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "ENABLE BCD"="FALSE"
                "ENABLE INTEGERS"="FALSE"
                "LIST SYNONYMS"="NONE"
                "ROWSET SIZE"="20"
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
                "OBJECT MODE"="TRUE"
            }

            "Database Engine\Settings\DRIVERS\ORACLE\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLORA32.DLL"
                "VENDOR INIT"="ORA73.DLL"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
            }

            "Database Engine\Settings\DRIVERS\SYBASE\DB OPEN" = @{
                "DATABASE NAME"=""
                "SERVER NAME"="SYB_SERVER"
                "USER NAME"="MYNAME"
                "OPEN MODE"="READ/WRITE"
                "SCHEMA CACHE SIZE"="8"
                "BLOB EDIT LOGGING"=""
                "LANGDRIVER"=""
                "SQLQRYMODE"="SERVER"
                "SQLPASSTHRU MODE"="SHARED AUTOCOMMIT"
                "DATE MODE"="1"
                "SCHEMA CACHE TIME"="-1"
                "MAX QUERY TIME"="300"
                "MAX ROWS"="-1"
                "BATCH COUNT"="200"
                "ENABLE SCHEMA CACHE"="FALSE"
                "SCHEMA CACHE DIR"=""
                "HOST NAME"=""
                "APPLICATION NAME"=""
                "NATIONAL LANG NAME"=""
                "ENABLE BCD"="FALSE"
                "TDS PACKET SIZE"="512"
                "BLOBS TO CACHE"="64"
                "BLOB SIZE"="32"
                "CS CURSOR ROWS"="1"
            }

            "Database Engine\Settings\DRIVERS\SYBASE\INIT" = @{
                "VERSION"="4.0"
                "TYPE"="SERVER"
                "DLL32"="SQLSYB32.DLL"
                "VENDOR INIT"=""
                "CONNECT TIMEOUT"="60"
                "TIMEOUT"="300"
                "DRIVER FLAGS"=""
                "TRACE MODE"="0"
                "MAX DBPROCESSES"="31"
            }

            "Database Engine\Settings\SYSTEM\FORMATS\DATE" = @{
                "SEPARATOR"="/"
                "MODE"="1"
                "FOURDIGITYEAR"="FALSE"
                "YEARBIASED"="TRUE"
                "LEADINGZEROM"="TRUE"
                "LEADINGZEROD"="FALSE"
            }

            "Database Engine\Settings\SYSTEM\FORMATS\NUMBER" = @{
                "DECIMALSEPARATOR"=","
                "THOUSANDSEPARATOR"="."
                "DECIMALDIGITS"="2"
                "LEADINGZERON"="TRUE"
            }

            "Database Engine\Settings\SYSTEM\FORMATS\TIME" = @{
                "TWELVEHOUR"="FALSE"
                "AMSTRING"="AM"
                "PMSTRING"="PM"
                "SECONDS"="TRUE"
                "MILSECONDS"="FALSE"
            }

        }

        if ($RadShared.Checked) {
            #caso seja compartilhado, valores padrão.
            $RegistryMap["Database Engine\Settings\DRIVERS\PARADOX\TABLE CREATE"] = @{
                "LEVEL"="7"
                "BLOCK SIZE"="2048"
                "FILL FACTOR"="95"
                "STRICTINTEGRTY"="TRUE"
            }

            $RegistryMap["Database Engine\Settings\DRIVERS\PARADOX\INIT"] = @{
                "VERSION"="4.0"
                "TYPE"="FILE"
                "LANGDRIVER"="ANSII850"
            }

            $RegistryMap["Database Engine\Settings\SYSTEM\INIT"] = @{
                "VERSION"="4.0"
                "LOCAL SHARE"="FALSE"
                "MINBUFSIZE"="128"
                "MAXBUFSIZE"="2048"
                "LANGDRIVER"="ANSII850"
                "MAXFILEHANDLES"="48"
                "SYSFLAGS"="0"
                "LOW MEMORY USAGE LIMIT"="32"
                "AUTO ODBC"="FALSE"
                "DEFAULT DRIVER"="PARADOX"
                "SQLQRYMODE"=""
                "MEMSIZE"="16"
                "SHAREDMEMSIZE"="2048"
                "SHAREDMEMLOCATION"=""
                "DATA REPOSITORY"=""
                "MTS POOLING"="FALSE"
            }

        }else{
            #se usado apenas para o Forponto, valores ideais.
            $RegistryMap["Database Engine\Settings\DRIVERS\PARADOX\TABLE CREATE"] = @{  
                "NET DIR"        = "$FpPath\Dados"
                "BLOCK SIZE"     = "65536"
                "FILL FACTOR"    = "95"
                "LEVEL"          = "7"
                "STRICTINTEGRTY" = "TRUE"
            }

            $RegistryMap["Database Engine\Settings\DRIVERS\PARADOX\INIT"] = @{
                "VERSION"        = "4.0"
                "TYPE"           = "FILE"
                "LANGDRIVER"     = "'ascii' ANSI"
            }

            $RegistryMap["Database Engine\Settings\SYSTEM\INIT"] = @{
                "VERSION"           = "4.0"
                "LOCAL SHARE"       = "TRUE"
                "DEFAULT DRIVER"    = "PARADOX"
                "LANGDRIVER"        = "'ascii' ANSI"
                "LOW MEMORY USAGE LIMIT" = "32"
                "MAXBUFSIZE"        = "8192"
                "MAXFILEHANDLES"    = "4096"
                "MEMSIZE"           = "205"
                "MINBUFSIZE"        = "128"
                "MTS POOLING"       = "FALSE"
                "SHAREDMEMLOCATION" = "5BDE"
                "SHAREDMEMSIZE"     = "8192"
                "SQLQRYMODE"        = ""
                "SYSFLAGS"          = "0"
                "AUTO ODBC"         = "FALSE"
                "DATA REPOSITORY"   = ""
            }
        }

        # arquivo cfg de backup
        $CfgFile = "$Path\IDAPI32.CFG"
        
        $BackupName = "IDAPI32_Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').CFG"
        $OldCfgPath = Join-Path $Path $BackupName
        
        $FoiRenomeado = $false
        
        if (Test-Path $CfgFile) {
            try {
                # Tenta renomear
                Move-Item -Path $CfgFile -Destination $OldCfgPath -Force -ErrorAction Stop
                $FoiRenomeado = $true
                Write-Host "Backup da configuracao encontrado e salvo como: $BackupName" -ForegroundColor Yellow
            } catch {
                Write-Warning "Falha ao criar backup do IDAPI32.CFG. Verifique se o arquivo está em uso."
                # Aqui você decide: para tudo ou continua? 
                # Geralmente, se falhou o backup, é arriscado continuar. 
                # Mas vamos apenas avisar e seguir para não travar o suporte.
            }
        } else {
            Write-Host "Nenhum arquivo IDAPI32.CFG encontrado. O script configurara o Registro para criar um novo padrao." -ForegroundColor DarkGray
        }

        # gravação das chaves e valores
        
        if (!(Test-Path $RegBase)) { 
            New-Item -Path $RegBase -Force | Out-Null 
            Write-Host "Criada chave base: $RegBase" -ForegroundColor Cyan
        }

        foreach ($SubKey in $RegistryMap.Keys) {
            $FullKeyPath = if ($SubKey -eq ".") { $RegBase } else { "$RegBase\$SubKey" }
            
            # Se a chave não existe, cria
            if (!(Test-Path $FullKeyPath)) { 
                New-Item -Path $FullKeyPath -Force | Out-Null
                Write-Host "Criada subchave: $SubKey" -ForegroundColor Cyan
            }

            # limpeza preventiva (modo dedicado em chaves INIT)
            if ($RadDed.Checked -and $SubKey -match "INIT$") {
                Write-Host "Limpeza na chave $SubKey..." -ForegroundColor DarkGray
                $PropriedadesAtuais = Get-ItemProperty -Path $FullKeyPath -ErrorAction SilentlyContinue
                
                if ($PropriedadesAtuais) {
                    foreach ($prop in $PropriedadesAtuais.PSObject.Properties) {
                        $Ignorar = @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")
                        if ($Ignorar -notcontains $prop.Name) {
                            Remove-ItemProperty -Path $FullKeyPath -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }
            }

            $ValuesHash = $RegistryMap[$SubKey]

            foreach ($ValueName in $ValuesHash.Keys) {
                $RawData = $ValuesHash[$ValueName]
                if ($null -ne $RawData) { $FinalData = $RawData.Replace("%PATH%", $Path) } else { $FinalData = "" }

                if ($RadDed.Checked) {
                    # se for dedicado, força a escrita
                    Set-ItemProperty -Path $FullKeyPath -Name $ValueName -Value $FinalData
                    Write-Host " [SET] $SubKey\$ValueName = $FinalData" -ForegroundColor DarkGray
                } else {
                    # se for compartilhado, só cria se não existir
                    $Current = Get-ItemProperty -Path $FullKeyPath -Name $ValueName -ErrorAction SilentlyContinue
                    
                    if ($null -eq $Current) {
                        Set-ItemProperty -Path $FullKeyPath -Name $ValueName -Value $FinalData
                        Write-Host " [NEW] $SubKey\$ValueName = $FinalData" -ForegroundColor Green
                    } else {
                        $ValAtual = $Current.$ValueName
                        Write-Host " [SKIP] $SubKey\$ValueName (Mantido: $ValAtual)" -ForegroundColor Yellow
                    }
                }
            }
        }

        # criar chave REPOSITORIES se não existir
        $RepoKey = "$RegBase\Database Engine\Settings\REPOSITORIES"
        if (!(Test-Path $RepoKey)) { 
            New-Item -Path $RepoKey -Force | Out-Null 
            Write-Host "Criada chave vazia: REPOSITORIES" -ForegroundColor Cyan
        }

        # registro da DLL de recursos compartilhados
        $TaskDll = Join-Path $FpPath "TaskRecursosCompartilhados.dll"
        
        if (Test-Path $TaskDll) {
            Write-Host "Tentando registrar TaskRecursosCompartilhados.dll..." -ForegroundColor Cyan
            
            $RegAsm = "$env:windir\Microsoft.NET\Framework\v4.0.30319\RegAsm.exe"
            
            if (Test-Path $RegAsm) {
                try {
                    $proc = Start-Process -FilePath $RegAsm -ArgumentList "`"$TaskDll`" /codebase /s" -Wait -PassThru -NoNewWindow
                    
                    if ($proc.ExitCode -eq 0) {
                        Write-Host "DLL registrada com sucesso via RegAsm." -ForegroundColor Green
                    } else {
                        Write-Host "Aviso: RegAsm retornou codigo de saida $($proc.ExitCode)." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Warning "Erro ao tentar executar o RegAsm: $_"
                }
            } else {
                Write-Warning "RegAsm.exe não encontrado. O registro da DLL não pôde ser feito."
            }
        }

        $HelpKeyPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\Help"
        if (!(Test-Path $HelpKeyPath)) { New-Item -Path $HelpKeyPath -Force | Out-Null }
        $HelpDir = if ($FpPath.EndsWith("\")) { $FpPath } else { "$FpPath\" }
        Set-ItemProperty -Path $HelpKeyPath -Name "Forponto.hlp" -Value $HelpDir

        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        
        # mensagem final
        $ModeMsg = if ($RadDed.Checked) { "Dedicado (Otimizado para o Forponto)" } else { "Compartilhado (Padrão)" }
        
        $FinalMessage = "Ambiente configurado com sucesso!`nModo: $ModeMsg"

        if ($FoiRenomeado) {
            $FinalMessage += "`n`nATENÇÃO:`n" +
                             "O arquivo de configuração original foi salvo na pasta do BDE como: " +
                             "'$BackupName'`n`n" +
                             "Caso precise recuperar bancos de dados (Aliases) antigos:`n" +
                             "1. Abra o BDE Administrator.`n" +
                             "2. Menu Object > Merge Configuration.`n" +
                             "3. Selecione o arquivo '$BackupName'."
        } else {
            $FinalMessage += "`n`nObservação: Não foi necessário fazer backup de configuração anterior (arquivo IDAPI32.CFG inexistente)."
        }
        
        [System.Windows.Forms.MessageBox]::Show($FinalMessage, "Concluído", "OK", "Information")
        $Form.Close()

    } catch {
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        [System.Windows.Forms.MessageBox]::Show("Erro: $($_.Exception.Message)", "Falha Crítica", "OK", "Error")
        $BtnGo.Text = "Executar"
        $BtnGo.Enabled = $true
    }
})

$Form.ShowDialog() | Out-Null