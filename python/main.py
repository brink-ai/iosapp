import os
# Set the API key as an environment variable
os.environ["TEAM_API_KEY"] = "4bf088eec18762baa35fffd45dec7901bb4d19521e6575cc36f0aac26eed5a09"
from aixplain.factories import ModelFactory, AgentFactory

def run_therapist_agent(user_query, audio=False, session_id=None):

    # Retrieve the agent using the ID
    agent = AgentFactory.get("67156f5cc784692b8d4c54a8")

    # Format the user query into the prompt
    prompt = f"You are a caring therapist. Based on {user_query}, give a supportive, unique response that acknowledges the user’s feelings and offers specific, actionable advice. Keep it under 200 words, avoiding generic statements."

    if session_id:
        agent_response = agent.run(prompt, session_id=session_id)
    else:
        # Run the agent with the user query
        agent_response = agent.run(prompt)

    # Extract the response and session ID
    response = agent_response["data"]["output"]
    session_id = agent_response["data"]["session_id"]

    # Print the results
    print("Response:", response)
    print("Session ID:", session_id)

    # If audio is enabled, play the audio response
    if audio:
        # Retrieve the speech synthesis agent
        speech_agent = ModelFactory.get("618cfb3b0981fd60e021cb0e")
        result = speech_agent.run(response)
        audio_url = result["data"]
        print("Audio URL:", audio_url)
        return session_id

    return session_id


user_query = "I feel overwhelmed by all the work I have to do."
response1 = run_therapist_agent(user_query, audio=True)
