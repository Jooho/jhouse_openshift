
~~~
git clone git@github.com:Jooho/jhouse_openshift.git

cd jhouse_openshift
~~~
## Deploy backend LLM

`source: AI-PoC/llama-stack/quick_start/README.md`

**Install/Deploy ollama**
~~~
curl -fsSL https://ollama.com/install.sh | sh
ollama run llama3.2:1b-instruct-fp16 --keepalive 60m

ctrl+D
~~~

**Deploy llama-stack**
~~~
export INFERENCE_MODEL="meta-llama/Llama-3.2-1B-Instruct"
export LLAMA_STACK_PORT=8321

mkdir -p ~/.llama

podman run -it --privileged \
-v ~/.llama:/root/.llama \
--network=host \
llamastack/distribution-ollama \
--port $LLAMA_STACK_PORT \
--env INFERENCE_MODEL=$INFERENCE_MODEL \
--env OLLAMA_URL=http://localhost:11434

# Check
curl localhost:${LLAMA_STACK_PORT}/v1/health
~~~


## Deploy Slack Bot/ Agent LLM App

`source: AI-PoC/slack-summary-using-llama-stack/slack_bot/README.md`
~~~
cd ../../slack-summary-using-llama-stack/slack_bot

python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

python app.py
~~~


## Deploy Agent LLM App 
`source: AI-PoC/slack-summary-using-llama-stack/summary_llm_agent/README.md`
~~~
cd ../summary_llm_agent

python -m venv venv
source venv/bin/activate  

python agent.py
~~~
