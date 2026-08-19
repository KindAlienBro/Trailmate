const fs = require('fs');
const pdfParse = require('pdf-parse');
const mammoth = require('mammoth');
const path = require('path');

const privacyPdf = path.join(__dirname, '..', 'privacy policy (1).pdf');
const termsDocx = path.join(__dirname, '..', 'VORNIITY_Terms_and_Conditions_Improved.docx');
const outputFile = path.join(__dirname, '..', 'lib', 'core', 'legal_docs.dart');

async function extract() {
    let privacyText = "";
    let termsText = "";

    try {
        let pdfBuffer = fs.readFileSync(privacyPdf);
        let pdfData = await pdfParse(pdfBuffer);
        privacyText = pdfData.text.replace(/'/g, "\\'").replace(/\$/g, "\\$");
    } catch (e) {
        console.error("Error reading PDF:", e);
        privacyText = "Privacy policy text goes here.";
    }

    try {
        let mammothResult = await mammoth.extractRawText({path: termsDocx});
        termsText = mammothResult.value.replace(/'/g, "\\'").replace(/\$/g, "\\$");
    } catch (e) {
        console.error("Error reading DOCX:", e);
        termsText = "Terms text goes here.";
    }

    const dartCode = `class LegalDocs {
  static const String privacyPolicy = r'''
${privacyText}
''';

  static const String termsAndConditions = r'''
${termsText}
''';
}
`;
    
    fs.writeFileSync(outputFile, dartCode);
    console.log("Dart file written successfully.");
}

extract();
