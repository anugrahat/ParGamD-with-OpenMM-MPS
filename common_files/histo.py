import pandas as pd
import matplotlib.pyplot as plt

# Define file path
file_path = 'histo.xvg'

# Read the file, keeping only numeric rows
data_rows = []
with open(file_path, 'r') as f:
    for line in f:
        # Skip lines starting with non-numeric characters
        if not line.strip().startswith(('#', '@')) and any(char.isdigit() for char in line):
            data_rows.append(line.strip().split())

# Convert the filtered rows into a DataFrame
data = pd.DataFrame(data_rows).apply(pd.to_numeric, errors='coerce')

# Extract X (reaction coordinate) and Y columns
x_histo = data.iloc[:, 0]
y_histo_columns = data.iloc[:, 1:]

# Plot the histograms
plt.figure(figsize=(10, 6))
for col in y_histo_columns.columns:
    plt.plot(x_histo, y_histo_columns[col], color='black')

plt.xlabel('Reaction Coordinate')
plt.ylabel('Distribution')
plt.title('Reaction Coordinate vs. Distribution (histo.xvg)')
plt.grid(False)
plt.tight_layout()
plt.show()
