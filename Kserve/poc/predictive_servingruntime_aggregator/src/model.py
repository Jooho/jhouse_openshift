import argparse
from typing import Dict, Union

from fastapi.middleware.cors import CORSMiddleware
from typing import Dict

import kserve
from kserve.protocol.infer_type import InferRequest, InferResponse
from kserve import Model, ModelServer, logging
from kserve.model_server import app
from lightgbm_model import LightGBMModel
from xgboost_model import XGBoostModel
from sklearn_model import SKLearnModel


class PredictiveModel(Model):
    def __init__(self, name: str, model_dir: str, nthread: int, framework: str):
        super().__init__(name)
        self._framework = framework
        if self._framework == "xgboost":
          self.model = XGBoostModel(name, model_dir, nthread)
        elif self._framework == "lightgbm":
          self.model = LightGBMModel(name, model_dir, nthread)
        elif self._framework == "sklearn":
          self.model = SKLearnModel(name, model_dir)
        self.ready = False

    def load(self):
        self.ready = self.model.load()
        return self.ready

    async def predict(
        self,
        payload: InferRequest,
        headers: Dict[str, str] = None,
    ) -> InferResponse:
        return self.model.predict(payload, headers)

DEFAULT_NTHREAD = 1

parser = argparse.ArgumentParser(
    parents=[kserve.model_server.parser]
)
parser.add_argument(
    "--model_dir", required=True, help="A local path to the model directory"
)
parser.add_argument(
    "--nthread",
    default=DEFAULT_NTHREAD,
    type=int,
    help="Number of threads to use by XGBoost or LightGBM.",
)
parser.add_argument("--framework", default="xgboost", type=str, help="which framework to use: xgboost, lightgbm, or sklearn")
args, _ = parser.parse_known_args()

if __name__ == "__main__":
    if args.configure_logging:
        logging.configure_logging(args.log_config_file)
    
    model = PredictiveModel(args.model_name, args.model_dir, args.nthread, args.framework)
    model.load()
    # Custom middlewares can be added to the model
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    ModelServer().start([model])
