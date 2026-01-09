![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)

## Verificador de Registros do Forponto (Forponto Registry Checker)

Automation and error correction tool developed in PowerShell to configure, fix, and 
optimize the environment for the proper functioning of the Borland Database Engine (BDE), essential for running 
the Forponto (Time & Attendance System).

Running legacy Delphi and BDE-based applications on modern versions of Windows (10/11/Server) 
often results in memory allocation errors, corrupted registry keys, and permission issues.
Constant updates and human management are highly prone to failure.

This program resolves these issues through:

-   **Native PowerShell GUI:** A complete graphical interface built with System.Windows.Forms 
    without external dependencies, allowing intuitive and simplified user interaction.
-   **Memory Correction (ASLR/Heap):** Applies specific `SHAREDMEMLOCATION` and `MEMSIZE` 
    configurations, preventing conflicts with modern Windows memory management.
-   **Registry Management (HKLM):** Maps and overwrites critical keys in `WOW6432Node`, ensuring 
    the integrity of the drivers used by the BDE.
-   **Auto-Elevation:** Automatically detects and requests UAC elevation if necessary.
-   **Dual Logging:** Displays real-time progress on screen while writing a detailed log file 
    for auditing.
-   **Dependency Registration:** Handles Forponto dependencies via `RegAsm`.
-   **Safety (Rollback):** Provides security via an Automatic System Restore Point, a Borland registry 
    backup, and configuration file (`IDAPI.CFG`) backups.
---
### How to Use:

1.  Download the `FpRegistry.exe` file.
2.  Run as **Administrator** (required for HKLM write access).
3.  Verify if the BDE and Forponto paths were correctly detected; if necessary, manually select the 
    correct path.
4.  Choose the specific usage profile:
        -   **Dedicated (Recommended):** Optimizes the BDE exclusively for Forponto, clearing unnecessary 
            settings,     maximizing buffers, and optimizing registry values.
        -   **Shared:** Maintains original settings and implements conservative values for missing entries. 
            This option should be selected if other software on the same machine uses the BDE and cannot 
            risk production downtime.
5.  Click **Execute**.
6.  Once finished, if you need to recover old aliases, follow these steps:
        1.  Open the **BDE Administrator**.
        2.  Go to the menu **Object > Merge Configuration**.
        3.  Select the backup file of the old CFG.
7.  The log is saved in the same folder as the executable.
---
## Technical Note:

The entire BDE registry structure was mapped into a nested Hash Table, facilitating maintenance and updates. Example:

    ```PowerShell
    $RegistryMap = @{
        "Database Engine\Settings\SYSTEM\INIT" = @{
            "LOCAL SHARE"       = "TRUE"
            "MEMSIZE"           = "205"  # Specific optimization
            "SHAREDMEMLOCATION" = "5BDE" # ASLR fix for x64
            # ...
        }
    }
    ```
---
### Disclaimer:

Although the script creates backups, always verify your environment before running it in a production setting.
---
*(Portuguese version below / Versão em Português abaixo)*

---

## Verificador de Registros do Forponto

Ferramenta de automação e correção de erros desenvolvida em PowerShell para configurar, 
corrigir e otimizar o ambiente para o correto funcionamento do Borland Database Engine
(BDE), necessário para a execução do sistema Forponto.

Rodar aplicações antigas baseadas em Delphi e BDE em versões modernas do Windows (10/11/Server)
muitas vezes resulta em erros de alocação de memória, chaves de registro corrompidas e problemas
de permissão. As constantes atualizações e gerenciamento humano é propenso a falhas.

O programa resolve esses problemas através de:

-   **GUI:** Interface gráfica completa nativa em PowerShell (System.Windows.Forms) sem
    dependências externas, permitindo com que o usuário interaja de forma intuitiva e simplificada.
-   **Correção de Memória (ASLR/Heap)**: aplicando configurações específicas de SHAREDMEMLOCATION e 
    MEMSIZE e evitando conflitos com o gerenciamento de memória do Windows moderno.
-   **Gestão de Registros (HKLM):** mapeando e reescrevendo chaves críticas no WOW6432Node, garantindo 
    integridade dos drivers utilizados pelo BDE.
-   **Auto-Elevação:**, detectando e solicitando elevação via UAC automaticamente se necessário.
-   **Log Duplo:**, exibindo o progresso na tela e gravando um arquivo de log detalhado para auditoria.
-   **Registro de dependências** do Forponto via RegAsm.
-   **Segurança (Rollback)**: via Ponto de Restauração Automático e backup do registro Borland e das 
    configurações anteriores (IDAPI.CFG)
---
### Como utilizar:

1.  Baixe o arquivo `FpRegistry.exe`.
2.  Execute como **administrador** (necessário para escrita em HKLM).
3.  Verifique se os caminhos do BDE e do Forponto foram detectados corretamente e, caso necessário, 
    selecione o caminho.
4.  Escolha o perfil de uso específico.
        -   **Dedicado (Recomendado):** Otimiza o BDE exclusivamente para o Forponto, limpando configurações 
            desnecessárias, maximizando buffers e otimizando os valores do registro.
        -   **Compartilhado:** Mantém configurações originais, e implementa valores conservadores no caso de 
            registros inexistente. Opção deve ser selecionada caso outros softwares utilizem o BDE na 
            mesma máquina e não podem quebrar em produção.
5.  Clique em **Executar**.
6.  Após a finalização, caso precise recuperar os alias antigos, siga os seguintes passos:
        1.  Abra o **BDE Administrator**.
        2.  Menu **Object > Merge Configuration**.
        3.  Selecione o arquivo de backup do antigo CFG.
7.  O log é salvo na mesma pasta do executável.
---
### Obs:

Toda estrutura do registro do BDE foi mapeada em uma Hash Table aninhada, facilitando a manutenção e 
acréscimo, se necessário. Exemplo:

    ```PowerShell
    $RegistryMap = @{
        "Database Engine\Settings\SYSTEM\INIT" = @{
            "LOCAL SHARE"       = "TRUE"
            "MEMSIZE"           = "205"  # Otimização específica
            "SHAREDMEMLOCATION" = "5BDE" # ASLR em x64
            # ...
        }
    }
    ```
---
## Aviso:

Apesar do script criar backups, sempre verifique seu ambiente antes de rodar em produção.

---