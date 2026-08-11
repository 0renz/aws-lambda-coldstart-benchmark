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
# Exibição da configuração
# ============================================

echo
echo "=========================================="
echo " Configuração das Lambdas"
echo "=========================================="
echo "Quantidade : $COUNT"
echo "Arquitetura: $TERRAFORM_ARCH"
echo "Memória    : ${MEMORY} MB"
echo "=========================================="
echo


# ============================================
# Terraform Init
# ============================================

echo "[1/3] Inicializando Terraform..."

terraform init


# ============================================
# Terraform Plan
# ============================================

echo
echo "[2/3] Criando plano..."

terraform plan \
    -var="lambda_count=$COUNT" \
    -var="lambda_architecture=$TERRAFORM_ARCH" \
    -var="lambda_memory_size=$MEMORY"


# ============================================
# Terraform Apply
# ============================================

echo
read -p "Deseja criar essas $COUNT Lambdas? [y/N] " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo
echo "[3/3] Criando Lambdas na AWS..."

terraform apply \
    -var="lambda_count=$COUNT" \
    -var="lambda_architecture=$TERRAFORM_ARCH" \
    -var="lambda_memory_size=$MEMORY" \
    -auto-approve


echo
echo "=========================================="
echo " Lambdas criadas com sucesso!"
echo "=========================================="

terraform output lambda_functions