# SEPA-to-Revolut-Payment-file-XSLT

As we're migrating to Revolut, and there is no support for handling SEPA XML-files, but only their own CSV-files, I needed to create a CSV-file with the info from the SEPA-XML. 

I did find an implementation in NodeJS at https://github.com/jessedvrs/convert-sepa-xml-to-revolut-csv-app - I just don't like an app that could be a tool. Main reason: eventually I want this to be part of an ELT. There was no easy way to separate the transformations from the rest of the app, so I made this. Second reason is that it does not read the address-info in the XML.

To make it simple and understandable, I chose XSLT. It's a powerful description-language for transforming/changing XML-files. XSLTs are very clean compared to code, unless there are many, many exceptions. I never made one for XML to CSV, but luckily Mistral did. To me the end-results looked good in my review.

It has only been tested with SEPA-files from the Dutch HR-service NMBRS, versions pain.001.001.09 and pain.001.001.03. It does work with XSLT 1.0, while there are some parts that could be more efficient in XSLT 2.0 - blame the availability of tools, that mostly sticked with XSLT 1.0.

To execute, you need an XSLT-processor. The easiest is using `xsltproc`, as there are binaries for any OS - even preinstalled on MacOS and many Linux distributions. But there are also libraries (or classes) for NodeJS/NodeRed, Python, JAVA, C++, you name it. 

Show output on screen:
> xsltproc sepa-to-revolut.xslt SEPA_2026_R05.xml

Or write to a file:
> xsltproc -o Revpay_2026_R05 sepa-to-revolut.xslt SEPA_2026_R05.xml

You probably want to change:
- defaultRecipientType
- defaultCountry

PRs welcome:
- tested with other sources - if it just works, then share in an issue
- other SEPA versions - unknown when the next pain is coming
- anonymized SEPA files
- better way for loading default values
- handling BUSINESS or PERSON
