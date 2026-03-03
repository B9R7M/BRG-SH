# Termos Técnicos Essenciais para Compilar ROMs AOSP

| Categoria             | Termo/Conceito        | Definição                                                                 |
|-----------------------|-----------------------|---------------------------------------------------------------------------|
| Repositórios          | Device tree           | Configurações específicas do hardware do dispositivo.                     |
|                       | Kernel source         | Código-fonte do kernel Linux adaptado para o dispositivo.                 |
|                       | Vendor blobs          | Binários proprietários do fabricante (drivers, bibliotecas).              |
|                       | Manifest              | Arquivo que define repositórios e branches a sincronizar.                 |
|                       | Branches              | Versões específicas do código (ex.: lineage-23.1, fourteen).              |
|                       | Codename              | Nome interno do dispositivo (ex.: pstar, tundra).                         |
| Processo de Build     | Repo                  | Ferramenta para gerenciar múltiplos repositórios Git no Android.          |
|                       | Sync                  | Processo de baixar/atualizar o código-fonte da ROM.                       |
|                       | Patches               | Alterações aplicadas ao código para corrigir ou adaptar funcionalidades.  |
|                       | Variants de build     | Tipos de compilação: `user`, `userdebug`, `eng`.                          |
|                       | Ccache                | Cache de compilação para acelerar builds subsequentes.                    |
|                       | Logs de compilação    | Arquivos que registram erros e progresso do build.                        |
| Hardware/Configuração | Swap                  | Espaço em disco usado como extensão da memória RAM.                       |
|                       | JOBS                  | Número de threads paralelas usadas na compilação.                         |
|                       | OOM Killer            | Mecanismo do Linux que encerra processos quando a memória acaba.          |
|                       | SSD NVMe vs SATA      | Tipos de armazenamento, com impacto direto na velocidade do build.        |
| Ferramentas/Linux     | Git                   | Sistema de controle de versão para clonar e gerenciar repositórios.       |
|                       | chmod / chown         | Comandos para alterar permissões de arquivos/diretórios.                  |
|                       | mkdir -p              | Criação de diretórios, mesmo que intermediários não existam.              |
|                       | tail / grep           | Comandos para inspecionar logs e localizar erros.                         |
| Diagnóstico/Manutenção| Branches incorretas   | Problema comum que impede compilação.                                     |
|                       | Backup & Restore      | Sistema para preservar modificações manuais.                              |
|                       | Certs (chaves)        | Arquivos que garantem compatibilidade entre builds.                       |
