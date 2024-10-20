import os
# Set the API key as an environment variable
os.environ["TEAM_API_KEY"] = "4bf088eec18762baa35fffd45dec7901bb4d19521e6575cc36f0aac26eed5a09"
from aixplain.factories import ModelFactory, AgentFactory

def run_therapist_agent(user_query, audio=False, session_id=None):

    # Retrieve the agent using the ID
    # gpt 4o: 67156f5cc784692b8d4c54a8
    # groq llama 3.1 70b: 6715762bc784692b8d4c56d6
    # groq mixstral: 671576a557c705a318033e76
    agent = AgentFactory.get("671576a557c705a318033e76")

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

    # If audio is enabled, play the audio response
    if audio:
        # Retrieve the speech synthesis agent
        speech_agent = ModelFactory.get("618cfb3b0981fd60e021cb0e")
        result = speech_agent.run(response)
        audio_url = result["data"]
        print("Audio URL:", audio_url)
        return response, session_id

    return response, session_id


# get user input
user_query = input("Hello! How are you feeling today? ")
response, id = run_therapist_agent(user_query, audio=True)
print(response)

# Continue asking for input until the user types 'stop'
while True:
    user_query = input("How are you feeling now? (Type 'stop' to exit) ")
    if user_query.lower() == 'stop':
        print("Thank you for the conversation. Take care!")
        break

    # Run the agent for the next user query
    response, session_id = run_therapist_agent(user_query, session_id=id)
    print(response)
