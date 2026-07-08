const axios = require('axios');

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

const query = `[out:json][timeout:15];
  (
    node["natural"="peak"](around:5000, 16.6089,74.7064);
  );
  out body 5;`;

async function run() {
  const headers = {
    'User-Agent': 'TrialMateApp/1.0',
    'Accept': 'application/json'
  };

  try {
    const res = await axios.post(OVERPASS_URL, `data=${encodeURIComponent(query)}`, {
      headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    console.log("Success:", res.data.elements.length);
  } catch (e) {
    console.error("Failed:", e.response?.status, e.response?.statusText);
    console.error(e.response?.data);
  }
}

run();
