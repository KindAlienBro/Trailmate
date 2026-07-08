const axios = require('axios');

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

const query = `[out:json][timeout:15];
  (
    node["natural"="peak"](around:5000, 16.6089,74.7064);
  );
  out body 5;`;

async function run() {
  const headers = {
    'User-Agent': 'TrialMateApp/1.0 (contact@trialmate.example)',
    'Accept': '*/*'
  };

  try {
    const res = await axios.post(OVERPASS_URL, query, {
      headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    console.log("Test (urlencoded raw text) Success:", res.data.elements.length);
  } catch (e) {
    console.error("Test 1 Failed:", e.response?.status, e.response?.statusText);
  }

  try {
    const res = await axios.post(OVERPASS_URL, `data=${encodeURIComponent(query)}`, {
      headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
    });
    console.log("Test 2 (urlencoded data=) Success:", res.data.elements.length);
  } catch (e) {
    console.error("Test 2 Failed:", e.response?.status, e.response?.statusText);
  }

  try {
    const res = await axios.post(OVERPASS_URL, query, {
      headers: { ...headers, 'Content-Type': 'text/plain' },
    });
    console.log("Test 3 (text/plain) Success:", res.data.elements.length);
  } catch (e) {
    console.error("Test 3 Failed:", e.response?.status, e.response?.statusText);
  }
}

run();
