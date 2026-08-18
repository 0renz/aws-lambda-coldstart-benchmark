#!/bin/bash

set -e

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
# Função para obter cold start
# ============================================
get_init_duration() {

    FUNCTION_NAME=$1
    START_TIME=$2

    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

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
            echo "$INIT_DURATION"
            return 0
        fi

        echo "Aguardando CloudWatch... tentativa $attempt/10"

        sleep 2
    done

    echo "N/A"
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
    START_TIME=$(date +%s000)

    echo
    echo "=========================================="
    echo "Lambda $((i + 1))/$COUNT"
    echo "=========================================="
    echo "Nome: $FUNCTION_NAME"
    echo

    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload '{"nome":"lorenzo"}' \
        --cli-binary-format raw-in-base64-out \
        /dev/stdout
    echo

    INIT_DURATION=$(get_init_duration "$FUNCTION_NAME" "$START_TIME")
    echo "Duração da inicialização: $INIT_DURATION ms"
done

echo
echo "=========================================="
echo " Invocações concluídas"
echo "=========================================="