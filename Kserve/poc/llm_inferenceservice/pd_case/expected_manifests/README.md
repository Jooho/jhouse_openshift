**vllm install**
~~~
python3.12 -m ensurepip --upgrade
python3.12 -m pip install --upgrade pip

python3.12 -m venv vllm-venv
source vllm-venv/bin/activate

which python
which pip

python -m pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0
python -m pip install xformers==0.0.29.post2
python -m pip install vllm
~~~