from flask import Flask, request, jsonify
import os


# Set the API key as an environment variable
os.environ["TEAM_API_KEY"] = "4bf088eec18762baa35fffd45dec7901bb4d19521e6575cc36f0aac26eed5a09"
import requests
from playsound import playsound
from pydub import AudioSegment
from pydub.playback import play
import io
from audioprocessing import convert_text_to_audio, convert_with_synthesis


from aixplain.factories import ModelFactory, AgentFactory

app = Flask(__name__)

def run_therapist_agent(user_query, audio=False, session_id=None):
    # Retrieve the agent using the ID
    agent = AgentFactory.get("67156f5cc784692b8d4c54a8")

    # Format the user query into the prompt
    prompt = f"You are a caring therapist. Based on {user_query}, give a supportive, unique response that acknowledges the user’s feelings and offers specific, actionable advice. Keep it under 200 words, avoiding generic statements."

    if session_id:
        # Continue the session using the provided session_id
        agent_response = agent.run(prompt, session_id=session_id)
    else:
        # Start a new session
        agent_response = agent.run(prompt)

    # Extract the response and session ID
    response = agent_response["data"]["output"]
    session_id = agent_response["data"]["session_id"]

    if audio:
       audio_wav = convert_text_to_audio(response)
       audio_final_link = convert_with_synthesis(response)
       return response, session_id, audio_final_link

    return response, session_id

# Flask route to expose the AI therapist agent
@app.route('/run_agent', methods=['POST'])
def agent_endpoint():
    # Extract data from the POST request
    data = request.get_json()
    user_query = data.get("user_query")
    session_id = data.get("session_id", None)  # Session ID is passed from the client
    audio = data.get("audio", False)

    # Run the agent
    result = run_therapist_agent(user_query, audio=audio, session_id=session_id)

    if len(result) == 3:
        response, session_id, audio_link = result
        return jsonify({
            "response": response,
            "session_id": session_id,
            "audio_link": audio_link
        })
    else:
        response, session_id = result
        return jsonify({
            "response": response,
            "session_id": session_id
        })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
