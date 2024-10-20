import requests
from playsound import playsound
from pydub import AudioSegment
from pydub.playback import play
import io
from aixplain.factories import ModelFactory, AgentFactory


def convert_text_to_audio(text):
    url = "https://api.aimlapi.com/tts"
    headers = {
        "Authorization": "Bearer 6cc1a747600d445f8f3274934c529fc0",
        "Content-Type": "application/json"
    }
    data = {
        "model": "#g1_aura-orpheus-en",
        "text": text
    }

    response = requests.post(url, json=data, headers=headers)

    # Ensure the request was successful
    if response.status_code == 201:
        # Load the audio file from the response content using io.BytesIO
        audio = AudioSegment.from_wav(io.BytesIO(response.content))
    else:
        print(f"Error: {response.status_code}, {response.text}")

    return response

def convert_with_synthesis(text):
    # Retrieve the speech synthesis agent
    speech_agent = ModelFactory.get("618cfb3b0981fd60e021cb0e")
    result = speech_agent.run(text)
    audio_url = result["data"]
    return audio_url
