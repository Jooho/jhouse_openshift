# Quick Start

## Deploy a ollama server

* Download ollama cli - [link](https://ollama.com/download)
  
* Run ollama server
~~~
ollama run llama3.2:1b-instruct-fp16 --keepalive 60m
~~~

* exit from the ollama terminal without killing the process
```
ctrl + D
```

* Check ollama server is still running
~~~
ollama ps
~~~


## Deploy llama stack container connected with the running ollama server

* Download template configuration
~~~
wget -L https://raw.githubusercontent.com/meta-llama/llama-stack/refs/heads/main/llama_stack/templates/ollama/run.yaml 
mv ./run.yaml /root/run.yaml
~~~

* Run llama-stack 
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
~~~

* Check llama-stack health
~~~
curl localhost:$LLAMA_STACK_PORT}/v1/health
~~~

## Test your first sample application with LLAMA Stack

* Install required lib in virtual environment
~~~
python3 -m venv venv
source ./venv/bin/activate

pip3 install -r requirements.txt
~~~

* Simple query using llama-stack-client cli
~~~
llama-stack-client \
  inference chat-completion \
  --message "hello, what model are you?
~~~


### First Inference
`first_inference.py` do the following:
- Show what models are available in the llama stack
- Send a simple quary to llama stack and stack will pass it to ollama
- Show the response 
~~~
python3 ./first_inference.py

...
--- Available models: ---
- all-MiniLM-L6-v2
- meta-llama/Llama-3.2-1B-Instruct

Here is a haiku about coding:

Bytes of code delight
Lines of logic dance on screen
Code's gentle hum
~~~
  
### First RAG_AGENT
`first_rag_agent.py` do the following:
- Create `LlamaStackAsLibraryClient` to work with a local llamaStack
- Create a vector server `sqllite` and insert several documents for RAG
- Create rag agent with `enable_session_persistence=true` so it keep the chat in to the memory
- Show the response 
~~~
python3 ./first_rag_agent.py
~~~

# Reference
- git@github.com:meta-llama/llama-stack-apps.git
- [Quick start](https://llama-stack.readthedocs.io/en/latest/getting_started/index.html#run-inference-with-python-sdk)
