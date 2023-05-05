*** Settings ***
Documentation      RobotSpareBin Industries Inc.에서 로봇을 주문
...                주문 HTML 영수증을 PDF 파일로 저장
...                주문한 로봇의 스크린샷을 저장
...                로봇의 스크린샷을 PDF 영수증에 삽입
...                영수증 및 이미지의 ZIP 아카이브 생성
Library    RPA.HTTP
Library    RPA.Excel.Files
Library    RPA.Tables
Library    RPA.Browser.Selenium    auto_close=${FALSE}
Library    RPA.PDF
Library    RPA.FileSystem
Library    RPA.Archive
Library    RPA.RobotLogListener

*** Variables ***
${CSV_URL}      https://robotsparebinindustries.com/orders.csv
${GLOBAL_RETRY_AMOUNT}=         3x
${GLOBAL_RETRY_INTERVAL}=       0.5s
${TEMP_OUTPUT_DIRECTORY}=       ${CURDIR}${/}temp

*** Tasks ***
RobotSpareBin Industries Inc.에서 로봇을 주문
    # Mute Run On Failure    # 실패 시 키워드가 스크린샷을 생성하는 것을 방지
    Open website
    Close the annoying modal
    Open the robot order website
    Create ZIP package from PDF files
    Cleanup temporary PDF directory
    Log    Done.

*** Keywords ***
Open website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order

Close the annoying modal
    # root > div > div.modal > div > div > div > div > div > button.btn.btn-dark
    Click Button    css:.btn-dark

Get orders
    # Download a CSV File from an HTTP server and overwrite existing file
    Download    ${CSV_URL}    overwrite=True
    # Source dialect is deduced automatically
    ${table}=    Read table from CSV    orders.csv
    Log   Found columns: ${table.columns}

    # Source dialect is known and given explicitly
    RETURN    ${table}

Open the robot order website
    ${orders}=    Get orders
    FOR    ${order}    IN    @{orders}
        # Log    ${order}[Order number]    level=INFO
        # Log    ${order}[Address]    level=INFO
        Wait Until Keyword Succeeds
    ...    ${GLOBAL_RETRY_AMOUNT}
    ...    ${GLOBAL_RETRY_INTERVAL}
    ...    Fill the form    ${order}
    END

Take a screenshot of the robot
    [Arguments]    ${order-number}
    ${screenshot}    Set Variable    ${TEMP_OUTPUT_DIRECTORY}${/}receipt_${order-number}.png
    Screenshot    id:receipt    ${screenshot}
    RETURN    ${screenshot}
   

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Add Watermark Image To PDF
    ...             image_path=${screenshot}
    ...             source_path=${pdf}
    ...             output_path=${pdf}
    # Close pdf    ${pdf}

Fill the form
    [Arguments]    ${order}
    Select From List By Index    head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    Input Text    css:.form-control    ${order}[Legs]
    Input Text    address    ${order}[Address]
    Sleep    1
    
    Get receipt page and keep clicking until success
    
    TRY
        Wait Until Element Is Visible    id:receipt
    EXCEPT    message
        Get receipt page and keep clicking until success
    END

    ${pdf}=    Store the receipt as a PDF file    ${order}[Order number]
    ${screenshot}=    Take a screenshot of the robot    ${order}[Order number]
    Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}

    Sleep    1
    Click Button    order-another
    Close the annoying modal
    
    # Submit Form
Get receipt page and keep clicking until success
    Wait Until Keyword Succeeds
    ...    ${GLOBAL_RETRY_AMOUNT}
    ...    ${GLOBAL_RETRY_INTERVAL}
    ...    Click Button    xpath://*[@id="order"]
            # //*[@id="order"]
            # /html/body/div/div/div[1]/div/div[1]/form/button[2]

Store the receipt as a PDF file
    [Arguments]    ${order-number}
    # Sleep    3
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    ${pdf}=    Set Variable    ${TEMP_OUTPUT_DIRECTORY}${/}receipt_${order-number}.pdf
    Html To Pdf    ${receipt_html}   ${pdf}
    RETURN    ${pdf}

Create ZIP package from PDF files
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/PDFs.zip
    Archive Folder With Zip
    ...    ${TEMP_OUTPUT_DIRECTORY}
    ...    ${zip_file_name}

Cleanup temporary PDF directory
    Remove Directory    ${TEMP_OUTPUT_DIRECTORY}    True