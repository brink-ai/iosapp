import os
# Set the API key as an environment variable
os.environ["TEAM_API_KEY"] = "4bf088eec18762baa35fffd45dec7901bb4d19521e6575cc36f0aac26eed5a09"

from aixplain.factories import AgentFactory
from aixplain.enums import Function, Supplier
from aixplain.modules.agent import PipelineTool
from aixplain.factories import AgentFactory


therapist = AgentFactory.create(
    name="Therapy Agent3",
    description="Analyzing user input and providing therapy",
    # required llm_id
    llm_id="65e1d442a4f0e436cfff4a20"
)

print("Therapy Agent id ", therapist.id)
