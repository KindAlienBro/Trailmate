const mammoth = require("mammoth");
const fs = require("fs");
const path = require("path");

const docxPath = "c:\\Users\\kinda\\StudioProjects\\Trialmate\\VORNIITY_Terms_and_Conditions_Improved.docx";
const outPath = "c:\\Users\\kinda\\StudioProjects\\Trialmate\\assets\\documents\\terms.txt";

mammoth.extractRawText({path: docxPath})
    .then(function(result){
        const text = result.value; // The raw text
        fs.writeFileSync(outPath, text);
        console.log("Successfully extracted text to " + outPath);
    })
    .catch(function(err){
        console.error(err);
    });
