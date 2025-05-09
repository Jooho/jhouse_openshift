📘 Tutorial: Build a Slackbot with LLM Agent using Ollama and Llama Stack

1. Create slackbot
  1. Gather messages by shortcut on thread.
2. Deploy ollama on local
3. Deploy LLAMA STACK connected with ollama
4. Create agent LLM



## Table of Contents

1.Introduction

- Overview of what we’re building
- High-level architecture
- Folder structure

  ```bash
  .
  ├── slack_bot/             # Slack bot codebase
  └── summary_llm_agent/     # LLM agent logic for summarizing threads
  ```

### Part 1: Create a Slack Bot

- Setting up a Slack App
- Enabling the message shortcut for threads
- Gathering thread messages using Slack API
- **Follow up [README.md](slack-summary-using-llama-stack/slack_bot/README.md)**


### Part 2: Deploy Ollama Locally
### Part 3: Set Up Llama Stack
- Install and run Ollama
- Load the desired LLM model (e.g., LLaMA 3, Mistral)
- Connect Llama Stack with your local Ollama
- API endpoints and configuration
- **Follow Up [README.md](../llama-stack/quick_start/README.md)**

### Part 4: Create the LLM Agent
- Design the summarization agent
- Use LlamaIndex or LangChain to manage prompts and tools
- Load thread content and return concise summaries
- **Follow Up [README.md](../summary_llm_agent/quick_start/README.md)**

### Part 5: Integrate Everything
- Connect Slack Bot to the LLM agent
- Send thread messages from slack_bot to summary_llm_agent
- Return summary back to the Slack thread

## Example

- Go to slack thread 
  ![alt text](image.png)

- Click "Loopy Thread"
  ![alt text](image-1.png)

- It showes summary
  ![alt text](image-2.png)  