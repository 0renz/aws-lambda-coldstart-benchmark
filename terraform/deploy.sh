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
# Invocar Lambdas
# ============================================

echo
echo "[4/4] Invocando Lambdas via aws invoke..."
echo


FUNCTIONS=$(terraform output -json lambda_functions)

for ((i=0; i<COUNT; i++)); do

    FUNCTION_NAME=$(echo "$FUNCTIONS" | jq -r ".[$i].name")

    echo
    echo "=========================================="
    echo "Lambda $((i + 1))/$COUNT"
    echo "=========================================="
    echo "Nome: $FUNCTION_NAME"
    echo

    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload '{"nome":"lorenzo"}' \
        "/responses/response_$((i + 1)).json" \
        --cli-binary-format raw-in-base64-out \
    echo "Resposta:"
    cat "response_$((i + 1)).json"
    echo

done

echo
echo "=========================================="
echo " Invocações concluídas"
echo "=========================================="