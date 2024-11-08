from flask import Flask, request, jsonify
from statistics import mean
import os
import requests
from dotenv import load_dotenv
from datetime import datetime

# Load environment variables
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"

app = Flask(__name__)


def calculate_sleep_duration(entry):
    # Parse the start and end times as datetime objects
    start_time = datetime.fromisoformat(entry[0])
    end_time = datetime.fromisoformat(entry[1])

    # Calculate the duration in hours
    duration = (end_time - start_time).total_seconds() / 3600
    return duration

def smooth_data(data, window_size=3):
    """Applies a simple moving average to smooth data."""
    smoothed = []
    for i in range(len(data)):
        window = data[max(0, i - window_size + 1): i + 1]
        smoothed.append(mean(window))
    return smoothed

def detect_trends(data):
    """Detects trends: 'increasing', 'decreasing', or 'stable'."""
    if all(x <= y for x, y in zip(data, data[1:])):
        return "increasing"
    elif all(x >= y for x, y in zip(data, data[1:])):
        return "decreasing"
    else:
        return "stable"

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    heart_rate = data.get("heart_rate")
    sleep = data.get("sleep")

    if not heart_rate or not sleep:
        return jsonify({"error": "Both 'heart_rate' and 'sleep' data are required."}), 400

    # Extract only the bpm values for heart rate
    heart_rate_values = [entry["bpm"] for entry in heart_rate]

    # Preprocess data
    smoothed_hr = smooth_data(heart_rate_values)
    sleep_durations = [(entry["start"], entry["end"]) for entry in sleep]  # Adjust as needed for sleep data processing
    hr_trend = detect_trends(smoothed_hr)
    sleep_trend = detect_trends([calculate_sleep_duration(entry) for entry in sleep_durations])  # If calculating sleep duration

    # Construct the prompt for Groq API
    prompt = (
        f"Analyze the following health data trends:\n"
        f"- Heart rate trend: {hr_trend} (based on recent measurements and averages)\n"
        f"- Sleep trend: {sleep_trend} (considering recent nightly durations and patterns)\n\n"
        f"Generate a structured analysis in JSON format with the following fields:\n\n"
        f"1. 'summary': A brief overview of the observed trends in heart rate and sleep data.\n\n"
        f"2. 'health_implications': Detailed discussion on the potential impact of these trends on the user's physical and mental well-being, including:\n"
        f"   - How changes in heart rate may relate to factors such as physical activity, stress levels, or cardiovascular health.\n"
        f"   - How variations in sleep patterns could affect energy levels, cognitive function, and emotional health.\n\n"
        f"3. 'recommendations': Specific, actionable advice tailored to the identified trends, focusing on achievable lifestyle adjustments. Include suggestions such as:\n"
        f"   - Relaxation techniques to manage stress.\n"
        f"   - Modifications to sleep hygiene practices.\n"
        f"   - Appropriate levels of physical activity.\n\n"
        f"4. 'risk_assessment': Evaluation of any potential health risks associated with the observed trends, categorized by severity (e.g., low, moderate, high).\n\n"
        f"5. 'data_quality': Assessment of the reliability of the provided data, noting any inconsistencies or areas requiring further monitoring.\n\n"
        f"6. 'additional_notes': Any other pertinent information or observations that could assist healthcare providers in understanding the user's health status.\n\n"
        f"Ensure the output is a valid JSON object with these fields, providing comprehensive insights to support therapeutic interventions."
    )

    # Call the Groq API
    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "llama3-8b-8192",  # Replace with your desired model
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 500,
        "response_format": {"type": "json_object"}
    }

    try:
        response = requests.post(GROQ_ENDPOINT, headers=headers, json=payload)
        response.raise_for_status()
        insight = response.json()
        return jsonify(insight)
    except requests.exceptions.HTTPError as errh:
        return jsonify({"error": f"HTTP Error: {errh}"}), 500
    except requests.exceptions.ConnectionError as errc:
        return jsonify({"error": f"Error Connecting: {errc}"}), 500
    except requests.exceptions.Timeout as errt:
        return jsonify({"error": f"Timeout Error: {errt}"}), 500
    except requests.exceptions.RequestException as err:
        return jsonify({"error": f"An Error Occurred: {err}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
