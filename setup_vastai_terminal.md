# Guide d'Intégration DeepSeek avec Vast.AI pour Choice App

Ce guide explique comment configurer votre propre terminal Vast.AI pour la génération automatique de posts dans Choice App.

## 1. Configuration du Terminal Vast.AI

### Prérequis
- Un compte Vast.AI avec des crédits
- Une instance ayant accès à DeepSeek

### Étapes de Configuration

1. **Déploiement de l'API DeepSeek**
   ```bash
   # Sur votre instance Vast.AI
   pip install deepseek-ai
   pip install fastapi uvicorn
   
   # Créer un fichier app.py
   cat > app.py << 'EOL'
   from fastapi import FastAPI, HTTPException
   from pydantic import BaseModel
   from typing import List, Optional
   import uvicorn
   import json
   
   # Mock pour l'exemple - à remplacer par l'intégration DeepSeek réelle
   from transformers import AutoTokenizer, AutoModelForCausalLM
   import torch
   
   app = FastAPI()
   
   # Chargement du modèle
   model_name = "deepseek-ai/deepseek-llm-7b-chat"  # ou autre modèle de votre choix
   tokenizer = AutoTokenizer.from_pretrained(model_name)
   model = AutoModelForCausalLM.from_pretrained(model_name, torch_dtype=torch.float16)
   
   class Message(BaseModel):
       role: str
       content: str
   
   class ChatRequest(BaseModel):
       messages: List[Message]
       temperature: Optional[float] = 0.7
       top_p: Optional[float] = 0.9
       max_tokens: Optional[int] = 500
   
   class Choice(BaseModel):
       message: Message
       index: int = 0
       
   class ChatResponse(BaseModel):
       id: str = "chat-1"
       choices: List[Choice]
       
   @app.post("/v1/chat/completions")
   async def chat_completion(request: ChatRequest):
       try:
           # Formater les messages pour DeepSeek
           prompt = ""
           for msg in request.messages:
               if msg.role == "system":
                   prompt += f"<|system|>\n{msg.content}</s>\n"
               elif msg.role == "user":
                   prompt += f"<|user|>\n{msg.content}</s>\n"
               elif msg.role == "assistant":
                   prompt += f"<|assistant|>\n{msg.content}</s>\n"
           
           prompt += "<|assistant|>\n"
           
           # Tokenisation et génération de texte
           inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
           outputs = model.generate(
               inputs.input_ids,
               max_new_tokens=request.max_tokens,
               temperature=request.temperature,
               top_p=request.top_p,
           )
           
           response_text = tokenizer.decode(outputs[0][inputs.input_ids.shape[1]:], skip_special_tokens=True)
           
           # Construction de la réponse
           return ChatResponse(
               choices=[
                   Choice(
                       message=Message(
                           role="assistant",
                           content=response_text
                       )
                   )
               ]
           )
       except Exception as e:
           raise HTTPException(status_code=500, detail=str(e))
   
   if __name__ == "__main__":
       uvicorn.run("app:app", host="0.0.0.0", port=8000)
   EOL
   
   # Lancer le serveur
   nohup python -m app &
   ```

2. **Exposition du Port via SSH Tunnel**
   ```bash
   # Si votre instance Vast.AI a déjà un tunnel SSH configuré
   # Si ce n'est pas le cas, consultez la documentation Vast.AI pour configurer un tunnel
   ```

3. **Test de l'API DeepSeek**
   ```bash
   curl -X POST "http://localhost:8000/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer sk-vastai-demo-key" \
     -d '{
       "messages": [
         {"role": "system", "content": "Vous êtes un assistant utile."},
         {"role": "user", "content": "Bonjour, comment allez-vous?"}
       ],
       "temperature": 0.7,
       "max_tokens": 100
     }'
   ```

## 2. Configuration de Choice App pour Utiliser Votre Terminal

### Création des Variables d'Environnement

1. **Créez ou modifiez le fichier .env dans votre backend**
   ```
   # Ajoutez ces lignes à votre fichier .env
   DEEPSEEK_URL=https://votre-adresse-vastai:port/
   DEEPSEEK_API_KEY=votre-clé-api
   ```

2. **Vérifiez que dotenv est correctement configuré**
   ```javascript
   // Vérifiez que cette ligne est présente au début de index.js
   require('dotenv').config();
   ```

### Test de l'Intégration

1. **Testez votre configuration**
   ```bash
   # Redémarrez votre serveur backend
   cd /chemin/vers/choice_app/backend
   node index.js
   
   # Testez la génération de posts
   curl -X GET "http://localhost:5000/api/ai/auto-posts/test"
   ```

2. **Vérifiez les logs**
   Regardez les logs du serveur pour confirmer que DeepSeek est correctement contacté et répond.

## 3. Dépannage

### Problèmes Courants

1. **Erreur 403 (Forbidden)**
   - Vérifiez votre clé API
   - Assurez-vous que les en-têtes d'autorisation sont correctement configurés

2. **Erreur de Connexion au Serveur**
   - Vérifiez que votre tunnel SSH est actif
   - Confirmez que le serveur FastAPI fonctionne sur votre instance Vast.AI
   - Vérifiez les certificats SSL si vous utilisez HTTPS

3. **Problème de Génération de Texte**
   - Vérifiez que le modèle DeepSeek est correctement chargé
   - Assurez-vous que les prompts sont correctement formatés

## 4. Monitoring et Maintenance

### Supervision du Service

1. **Logs Automatiques**
   - Les logs sont disponibles dans la console où vous avez lancé le serveur backend
   - Vous pouvez également consulter `/api/ai/auto-posts/stats` pour voir les statistiques

2. **Redémarrage Automatique**
   ```bash
   # Sur votre instance Vast.AI, installez PM2 pour une gestion robuste des processus
   npm install -g pm2
   pm2 start app.py --interpreter=python3
   pm2 save
   pm2 startup
   ```

### Mise à Jour du Modèle

Si vous souhaitez utiliser un modèle DeepSeek différent ou mettre à jour le modèle existant:

1. Modifiez la variable `model_name` dans votre script app.py
2. Redémarrez le serveur FastAPI

## 5. Validation Complète

Pour vous assurer que tout fonctionne correctement:

1. **Testez la Génération de Posts à Partir du Test Endpoint**
   ```
   GET /api/ai/auto-posts/test
   ```

2. **Vérifiez que le Post a Été Créé en Base de Données**
   ```javascript
   // Dans mongo shell
   use choice_app
   db.Posts.find({is_automated: true}).sort({time_posted: -1}).limit(1)
   ```

3. **Confirmez l'Affichage du Post dans l'Application**
   Connectez-vous à l'application et vérifiez que le post apparaît dans le feed.