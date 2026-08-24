const axios = require('axios');

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

const query = `[out:json][timeout:15];
  (
    nwr["tourism"="attraction"]["name"](around:50000, 28.6139, 77.2090);
  );
  out center 5;`;

async function run() {
  const headers = {
    'User-Agent': 'TrialMateApp/1.0',
    'Accept': 'application/json'
  };

  try {
    const res = await axios.post(OVERPASS_URL, `data=${encodeURIComponent(query)}`, {
      headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    console.log("Success:", JSON.stringify(res.data.elements, null, 2));
  } catch (e) {
    console.error("Failed:", e.response?.status, e.response?.statusText);
    console.error(e.response?.data);
  }
}

run();
