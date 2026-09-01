#!/bin/bash

set -e

# Diretório raiz do projeto
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Diretórios
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
RESULTS_DIR="$PROJECT_ROOT/results"

# Arquivo CSV
CSV_FILE="$RESULTS_DIR/init_duration_results.csv"

# Criar diretório de resultados caso não exista
mkdir -p "$RESULTS_DIR"

cd "$TERRAFORM_DIR"

# ============================================
# Validação dos argumentos
# ============================================

if [ "$#" -ne 3 ]; then
    echo "Uso:"
    echo "  $0 <quantidade> <arquitetura> <memoria>"
    echo
    echo "Exemplos:"
    echo "  $0 10 x86 128"
    echo "  $0 10 arm 512"
    exit 1
fi

COUNT=$1
ARCH=$2
MEMORY=$3


# ============================================
# Validação da quantidade
# ============================================

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
    echo "Erro: quantidade deve ser um número inteiro maior que 0."
    exit 1
fi


# ============================================
# Conversão da arquitetura
# ============================================

case "$ARCH" in
    x86)
        TERRAFORM_ARCH="x86_64"
        ;;

    arm)
        TERRAFORM_ARCH="arm64"
        ;;

    *)
        echo "Erro: arquitetura inválida."
        echo
        echo "Use:"
        echo "  x86"
        echo "  arm"
        exit 1
        ;;
esac


# ============================================
# Validação da memória
# ============================================

if ! [[ "$MEMORY" =~ ^[0-9]+$ ]]; then
    echo "Erro: memória deve ser um número."
    exit 1
fi


# ============================================
# Terraform Init
# ============================================

echo "[1/4] Inicializando Terraform..."

terraform init


# ============================================
# Terraform Plan
# ============================================

echo
echo "[2/4] Criando plano..."

terraform plan \
    -var="lambda_count=$COUNT" \
    -var="lambda_architecture=$TERRAFORM_ARCH" \
    -var="lambda_memory_size=$MEMORY"


# ============================================
# Confirmação
# ============================================

echo
read -p "Deseja criar essas $COUNT Lambdas? [y/N] " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Operação cancelada."
    exit 0
fi


# ============================================
# Terraform Apply
# ============================================

echo
echo "[3/4] Criando Lambdas e Function URLs..."

terraform apply \
    -var="lambda_count=$COUNT" \
    -var="lambda_architecture=$TERRAFORM_ARCH" \
    -var="lambda_memory_size=$MEMORY" \
    -auto-approve


# ============================================
# Obter URLs
# ============================================

echo
echo "=========================================="
echo " Lambdas criadas"
echo "=========================================="

terraform output lambda_functions

# ============================================
# Função que obtém cold start, armazena o nome da função e o tempo de início em uma tabela .csv
# ============================================
get_init_duration() {

    FUNCTION_NAME=$1
    CSV_FILE="$PROJECT_ROOT/results/init_duration_results.csv"  # Trocar de diretório para fora do Terraform, talvez?
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    ARCHITECTURE=$2
    MEMORY_SIZE=$3

    if [ ! -f "$CSV_FILE" ]; then
        echo "function_name,architecture,memory_size,init_duration_ms" > "$CSV_FILE"
    fi

    for attempt in {1..10}; do

        LOG=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time "$START_TIME" \
            --filter-pattern "REPORT" \
            --query 'events[*].message' \
            --output text 2>/dev/null || true)

        INIT_DURATION=$(echo "$LOG" |
            grep -oP 'Init Duration: \K[0-9.]+' |
            tail -1)

        if [ -n "$INIT_DURATION" ]; then

            echo "Init Duration: ${INIT_DURATION} ms"

            # Salva no CSV
            echo "$FUNCTION_NAME,$ARCHITECTURE,$MEMORY_SIZE,$INIT_DURATION" \
                >> "$CSV_FILE"

            return 0
        fi

        echo "Aguardando CloudWatch... tentativa $attempt/10"

        sleep 2
    done

    echo "Init Duration não encontrado."

    # Registra também quando não foi possível obter a métrica
    echo "$FUNCTION_NAME,$ARCHITECTURE,$MEMORY_SIZE,N/A" \
        >> "$CSV_FILE"

    return 1
}

# ============================================
# Invocar Lambdas
# ============================================

echo
echo "[4/4] Invocando Lambdas via aws invoke..."
echo


FUNCTIONS=$(terraform output -json lambda_functions)

for ((i=0; i<COUNT; i++)); do

    FUNCTION_NAME=$(echo "$FUNCTIONS" | jq -r ".[$i].name")
    ARCHITECTURE=$(echo "$FUNCTIONS" | jq -r ".[$i].architecture")
    MEMORY_SIZE=$(echo "$FUNCTIONS" | jq -r ".[$i].memory")

    echo
    echo "=========================================="
    echo "Lambda $((i + 1))/$COUNT"
    echo "=========================================="
    echo "Nome        : $FUNCTION_NAME"
    echo "Arquitetura : $ARCHITECTURE"
    echo "Memória     : ${MEMORY_SIZE} MB"
    echo

    START_TIME=$(date +%s000)

    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload "{\"queryStringParameters\":{\"test\":\"cold-start\",\"lambda\":\"$((i + 1))\"}}" \
        --cli-binary-format raw-in-base64-out \
        /dev/null

    echo

    INIT_DURATION=$(get_init_duration "$FUNCTION_NAME" "$ARCHITECTURE" "$MEMORY_SIZE")
    echo "Duração da inicialização: $INIT_DURATION ms"
done

echo
echo "=========================================="
echo " Invocações concluídas"
echo "=========================================="