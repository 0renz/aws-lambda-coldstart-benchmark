import json


def handler(event, context):
    """
    Função Lambda simples - Hello World.
    """
    nome = event.get("nome", "mundo") if isinstance(event, dict) else "mundo"
    
    corpo = {
        "mensagem": f"Ola, {nome}! Lambda executada com sucesso."
    }
    
    print(corpo["mensagem"])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(corpo, ensure_ascii=False)
    }
