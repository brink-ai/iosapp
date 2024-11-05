from flask import Flask, request, jsonify
import os
import pinecone
from uuid import uuid4
from dotenv import load_dotenv
# Import the Pinecone library
from pinecone.grpc import PineconeGRPC as Pinecone
from pinecone import ServerlessSpec

# Get the OpenAI API key and Pinecone API key from the environment variables
load_dotenv()
openai_api_key = os.getenv("OPENAI_API_KEY")
pinecone_api_key = os.getenv("PINECONE_API_KEY")
if not openai_api_key or not pinecone_api_key:
    print("Please set the OPENAI_API_KEY and PINECONE_API_KEY environment variables.")
# Initialize a Pinecone client with your API key
pc = Pinecone(api_key=pinecone_api_key)
index = pc.Index("embeddings")

# Initialize Flask app
app = Flask(__name__)

# # Function to generate an embedding for a given text using Pinecone's embedding model
# def get_embedding(text):
#     # Convert the text into numerical vectors that Pinecone can index
#     response = pc.inference.embed(
#         model="multilingual-e5-large",  # Replace with your preferred model if different
#         inputs=[text],
#         parameters={"input_type": "passage", "truncate": "END"}
#     )
#     return response.data[0]['values']  # Returns the embedding vector

# Function to process the user's query, save the embedding to Pinecone, and retrieve similar responses
def run_therapist_agent(user_query):
    # # Generate embedding for the user query
    # embedding = get_embedding(user_query)

    # Save the query to Pinecone with a unique identifier
    unique_id = str(uuid4())
    index.upsert([(unique_id, user_query)])

    # Query Pinecone to find similar embeddings to provide a contextual response
    results = index.query(vector=user_query, top_k=5, include_metadata=True)
    response_text = " ".join(match['metadata'].get('text', '') for match in results['matches'])

    return response_text

# Single endpoint to handle query processing and response generation
@app.route('/query', methods=['POST'])
def query_theravoice():
    data = request.get_json()
    user_query = data.get("text")

    # Process the user query
    response_text = run_therapist_agent(user_query)

    return jsonify({"response": response_text})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
