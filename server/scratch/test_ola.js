const axios = require('axios');
const API_KEY = 'Txtd52X2o49O1UlPk7euny0DUhjd65VGQaMWzBoR';
async function test() {
  const origin = '12.9348,77.6189';
  const destination = '12.9716,77.5946';
  for (let mode of ['driving', 'two_wheeler', 'walking']) {
    try {
      const res = await axios.post(`https://api.olamaps.io/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${API_KEY}&mode=${mode}`);
      const route = res.data.routes[0];
      const dist = route.legs[0].distance;
      const dur = route.legs[0].duration;
      console.log(`Mode: ${mode}, Distance: ${dist}, Duration: ${dur}`);
    } catch(e) {
      console.log(`Mode ${mode} error: ${e.response?.data?.message || e.message}`);
    }
  }
}
test();
