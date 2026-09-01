
Projeto de Trabalho de Conclusão de Curso (TCC2) que implementa **Infrastructure as Code (IaC)** usando Terraform e Shell script para provisionar, executar e recuperar o tempo de *cold start* de funções AWS Lambda em diferentes configurações de arquitetura e memória.

## Objetivos

- Provisionar infraestrutura na AWS utilizando Terraform
- Criar funções Lambda configuráveis em quantidade, arquitetura e memória
- Medir e registrar o tempo de inicialização das Lambdas
- Coletar e analisar dados de desempenho em diferentes configurações
- Provisionar análises automatizadas usando ferramentas de manipulação de dados (A FAZER) 

## Estrutura do Projeto

```
.
├── terraform/          # Definições de infraestrutura Terraform
│   ├── main.tf         # Recursos principais (Lambdas, IAM, CloudWatch)
│   ├── variables.tf    # Variáveis de entrada
│   ├── outputs.tf      # Saídas da infraestrutura
│   └── versions.tf     # Configurações de versão e providers
├── src/
│   └── index.py        # Código Python da função Lambda
├── scripts/
│   └── deploy.sh       # Script de deploy e testes
├── results/            # Diretório de resultados (CSV com métricas)
└── build/              # Artefatos compilados (ZIP das Lambdas)
```

## Como Usar

### Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurada com credenciais válidas
- Bash
- `jq` para processar JSON
- Acesso à AWS com permissões para criar Lambda, IAM, CloudWatch

### Deployment

Execute o script de deploy com os seguintes parâmetros:

```bash
./scripts/deploy.sh <quantidade> <arquitetura> <memoria>
```

**Parâmetros:**
- `<quantidade>`: Número de Lambdas a criar (ex: 10)
- `<arquitetura>`: `x86` ou `arm`
- `<memoria>`: Tamanho de memória em MB (128, 256, 512, 1024, 2048, 3008)

**Exemplos:**

```bash
# Criar 10 Lambdas com arquitetura x86 e 128MB
./scripts/deploy.sh 10 x86 128

# Criar 5 Lambdas com arquitetura arm64 e 512MB
./scripts/deploy.sh 5 arm 512
```

### O que o script faz

1. **Validação** - Verifica argumentos (quantidade, arquitetura, memória)
2. **Terraform Init** - Inicializa o estado do Terraform
3. **Terraform Plan** - Gera plano de execução
4. **Confirmação** - Aguarda confirmação do usuário
5. **Terraform Apply** - Cria recursos na AWS
6. **Invocação** - Invoca cada Lambda para capturar cold start
7. **Coleta de Métricas** - Extrai Init Duration do CloudWatch e salva em CSV

### Resultados

Os dados de desempenho são salvos em `results/init_duration_results.csv`:

```csv
function_name,architecture,memory_size,init_duration_ms
lambda-01-x86-128mb,x86_64,128,245.32
lambda-02-x86-128mb,x86_64,128,238.15
```

## Configuração da Infraestrutura

### Variáveis Terraform

Customize as variáveis no arquivo [terraform/variables.tf](terraform/variables.tf):

- **aws_region**: Região AWS (padrão: `us-east-1`)
- **function_name**: Nome base das funções Lambda (padrão: `lambda`)
- **runtime**: Python runtime (padrão: `python3.12`)
- **environment**: Tag de ambiente (padrão: `dev`)
- **lambda_memory_size**: Memória em MB (padrão: 2048)
- **lambda_architecture**: Arquitetura (padrão: `arm64`)
- **lambda_count**: Quantidade de Lambdas (padrão: 1)

### Recursos Criados

- **AWS Lambda Functions**: Múltiplas instâncias conforme parâmetros
- **IAM Role**: Permissões para execução e logs
- **CloudWatch Log Groups**: Armazenamento de logs com retenção de 14 dias
- **Logs Policy**: Permissão para escrever logs na AWS

## Código Lambda

O código da função Lambda em [src/index.py](src/index.py) é um template simples que:

- Recebe eventos da API Gateway
- Log das mensagens recebidas
- Retorna resposta JSON com os parâmetros recebidos

## Análise de Desempenho

O projeto coleta métricas de cold start (Init Duration) de cada Lambda invocada, permitindo comparar:

- **Impacto da arquitetura**: x86 vs arm64
- **Impacto da memória**: Como o tamanho de memória afeta o desempenho
- **Variabilidade**: Padrão de comportamento entre múltiplas invocações


## Autor
Lorenzo Costa Schauenberg