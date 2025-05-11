#!/usr/bin/env python3

import csv
import os
from datetime import datetime
import sys

if len(sys.argv) < 2:
    print("Usage: python wise_to_mercury.py <input_file>")
    sys.exit(1)

# use arg for path:
input_file = sys.argv[1]
# replace some/file.csv with some/file.mercury.csv:
output_file = input_file.replace(".csv", ".mercury.csv")

# Define output columns
output_columns = [
    "Date (UTC)",
    "Description",
    "Amount",
    "Status",
    "Source Account",
    "Bank Description",
    "Reference",
    "Note",
    "Last Four Digits",
    "Name On Card",
    "Category",
    "GL Code",
    "Timestamp",
    "Original Currency",
    "Check Number",
    "Tags",
]


def convert_date(date_str):
    """Convert date from DD-MM-YYYY to YYYY-MM-DD"""
    if not date_str:
        return ""
    try:
        day, month, year = date_str.split("-")
        return f"{year}-{month}-{day}"
    except:
        return date_str


print(f"Reading file: {input_file}")
with open(input_file, "r", newline="", encoding="utf-8") as infile, open(
    output_file, "w", newline="", encoding="utf-8"
) as outfile:

    reader = csv.DictReader(infile)
    writer = csv.DictWriter(outfile, fieldnames=output_columns)
    writer.writeheader()

    for row in reader:
        # Format date to YYYY-MM-DD
        formatted_date = convert_date(row["Date"])

        # Create new row with mapped columns
        new_row = {
            "Date (UTC)": formatted_date,
            "Description": row["Description"],
            "Amount": row["Amount"],
            "Status": "Completed",
            "Source Account": "Wise",
            "Bank Description": row["Description"],
            "Reference": row.get("Payment Reference", ""),
            "Note": row.get("Note", ""),
            "Last Four Digits": row.get("Card Last Four Digits", ""),
            "Name On Card": row.get("Card Holder Full Name", ""),
            "Category": "",
            "GL Code": "",
            "Timestamp": f"{formatted_date} 00:00:00",
            "Original Currency": row["Currency"],
            "Check Number": "",
            "Tags": "",
        }

        writer.writerow(new_row)

print(f"Conversion complete. Output saved to {output_file}")
