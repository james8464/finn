"""Build the constant-output Core ML fixture used by FinnTests.

The fixture is NOT a trained model and says nothing about recognition accuracy. It has the
interface of a Create ML action classifier (a "poses" input of shape [window, 3, 18], a "label"
output and a "labelProbabilities" output) and always answers push_up with probability 0.92, so
the app's loading and parsing code can be tested on the simulator.

    python3 -m venv /tmp/coreml && /tmp/coreml/bin/pip install coremltools
    /tmp/coreml/bin/python tools/exercise-classifier/make_test_fixture.py
"""

from pathlib import Path

import numpy as np
from coremltools.models import MLModel, datatypes
from coremltools.models.neural_network import NeuralNetworkBuilder

LABELS = ["none", "other", "push_up", "squat", "static_lunge", "stiff_leg_deadlift"]
WINDOW = 30
OUTPUT = (
    Path(__file__).resolve().parents[2] / "Finn/FinnTests/Fixtures/ConstantPushUpClassifierFixture.mlmodel"
)


def build() -> MLModel:
    builder = NeuralNetworkBuilder(
        [("poses", datatypes.Array(WINDOW, 3, 18))],
        [("labelProbabilities", datatypes.Array(len(LABELS)))],
        mode="classifier",
    )
    builder.add_flatten(name="flatten", mode=0, input_name="poses", output_name="flat")
    bias = np.zeros(len(LABELS))
    bias[LABELS.index("push_up")] = np.log(0.92 * (len(LABELS) - 1) / 0.08)
    builder.add_inner_product(
        name="constant",
        W=np.zeros((len(LABELS), WINDOW * 54)),
        b=bias,
        input_channels=WINDOW * 54,
        output_channels=len(LABELS),
        has_bias=True,
        input_name="flat",
        output_name="logits",
    )
    builder.add_softmax(name="softmax", input_name="logits", output_name="labelProbabilities")
    builder.set_class_labels(LABELS, predicted_feature_name="label", prediction_blob="labelProbabilities")
    spec = builder.spec
    spec.description.metadata.shortDescription = (
        "Test fixture with constant output. Never trained; not a Finn exercise model."
    )
    spec.description.metadata.userDefined["finn.targetFrameRate"] = "15.0"
    spec.description.metadata.userDefined["finn.predictionWindow"] = str(WINDOW)
    return MLModel(spec)


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(str(OUTPUT))
    print(f"wrote {OUTPUT}")
