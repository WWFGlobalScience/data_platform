myws= "C:/Users/mills/OneDrive - World Wildlife Fund, Inc/Documents/data_platform/data_platform/Conservation_Activities"
setwd(myws)
getwd()

#out_folder= "L:/data_platform/Analysis/Prod_outputs/Cons_activities/PA_Pie_Charts/"
#out_folder= "L:/data_platform/Analysis/Prod_outputs/Cons_activities/KBA_Pie_Charts/"
#out_folder= "L:/data_platform/Analysis/Prod_outputs/Cons_activities/KBA_PA_Pie_Charts/"
out_folder= "L:/data_platform/Analysis/Prod_outputs/Cons_activities/IUCN_Bar_Charts/"

library(ggplot2)
library(dplyr)
library(tidyr)
library(ggrepel)
library(scales)

# Load the data
data<- read.csv("CA_Scapes_output.csv")
print(data)

test<-head(data, 2)
print(test)

#PA pie chart
# --- Loop through each row and create a pie chart ---
for (i in 1:nrow(data)) {
  
  # Extract current row
  row_data <- data[i, ]
  
  # Create pie chart data frame
  pie_data <- data.frame(
    Category = c("Protected Area", "Non-Protected Area"),
    Area_HA = c(row_data$PA_HA, row_data$NP_HA)
  ) %>%
    mutate(
      #Category = factor(Category, levels = c("Protected Area", "Non-Protected Area")),
      Percent = Area_HA / sum(Area_HA) * 100,
      Label = paste0(format(round(Area_HA, 0), big.mark = ","), " ha", 
                     "\n", sprintf("%.0f%%", Percent))
    )
  
  # Create pie chart
  p <- ggplot(pie_data, aes(x = "", y = Area_HA, fill = Category)) +
    geom_col(width = 1, color = "white") +
    coord_polar(theta = "y") +
    #geom_label_repel(aes(label = Label, y = Area_HA),
        #nudge_x = 1, show.legend = FALSE,
        #size = 4, color = "black", segment.color = "grey30")+
    geom_text(aes(label = Label), position = position_stack(vjust = .5), size = 4, color = "black") +
    #scale_fill_manual(values = c("#12a25e", "#ff9f0a")) +
    scale_fill_manual(
      values = c("Non-Protected Area" = "#ff9f0a", "Protected Area" = "#12a25e"),
      breaks = c("Protected Area", "Non-Protected Area" )   # legend order only
      )+
    labs(title = paste("Protected Area in", row_data$Name, "\n", "(hectares, %)")) +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))
  
  # Show the chart
  #print(p)
  
  # --- Optional: Save each chart as a PNG file ---
  ggsave(filename = paste0(out_folder,"PApie_", gsub(" ", "_", row_data$ID), ".png"), plot = p, width = 6, height = 6)
}



#KBA pie chart
# --- Loop through each row and create a pie chart ---
for (i in 1:nrow(data)) {
  
  # Extract current row
  row_data <- data[i, ]
  
  # Create pie chart data frame
  pie_data <- data.frame(
    Category = c("KBA", "Not KBA"),
    Area_HA = c(row_data$KBA_HA, row_data$Non_KBA_HA)
  ) %>%
    mutate(
      #Category = factor(Category, levels = c("Protected Area", "Non-Protected Area")),
      Percent = Area_HA / sum(Area_HA) * 100,
      Label = paste0(format(round(Area_HA, 0), big.mark = ","), " ha", 
                     "\n", sprintf("%.0f%%", Percent))
    )
  
  # Create pie chart
  p <- ggplot(pie_data, aes(x = "", y = Area_HA, fill = Category)) +
    geom_col(width = 1, color = "white") +
    coord_polar(theta = "y") +
    #geom_label_repel(aes(label = Label, y = Area_HA),
    #nudge_x = 1, show.legend = FALSE,
    #size = 4, color = "black", segment.color = "grey30")+
    geom_text(aes(label = Label), position = position_stack(vjust = .5), size = 4, color = "black") +
    #scale_fill_manual(values = c("#12a25e", "#ff9f0a")) +
    scale_fill_manual(
      values = c("Not KBA" = "#ffd621", "KBA" = "#167c85"),
      breaks = c("KBA", "Not KBA" )   # legend order only
    )+
    labs(title = paste("Key Biodiversity Areas in", row_data$Name, "\n", "(hectares, %)")) +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))
  
  # Show the chart
  #print(p)
  
  # --- Optional: Save each chart as a PNG file ---
  ggsave(filename = paste0(out_folder,"KBApie_", gsub(" ", "_", row_data$ID), ".png"), plot = p, width = 6, height = 6)
}


#KBA PA pie chart
# --- Loop through each row and create a pie chart ---
for (i in 1:nrow(data)) {
  
  # Extract current row
  row_data <- data[i, ]
  
  # Create pie chart data frame
  pie_data <- data.frame(
    Category = c("KBAs Protected", "KBAs Not Protected"),
    Area_HA = c(row_data$KBA_PA_HA, row_data$KBA_NP_HA)
  ) %>%
    mutate(
      #Category = factor(Category, levels = c("Protected Area", "Non-Protected Area")),
      Percent = Area_HA / sum(Area_HA) * 100,
      Label = paste0(format(round(Area_HA, 0), big.mark = ","), " ha", 
                     "\n", sprintf("%.0f%%", Percent))
    )
  
  # Create pie chart
  p <- ggplot(pie_data, aes(x = "", y = Area_HA, fill = Category)) +
    geom_col(width = 1, color = "white") +
    coord_polar(theta = "y") +
    #geom_label_repel(aes(label = Label, y = Area_HA),
    #nudge_x = 1, show.legend = FALSE,
    #size = 4, color = "black", segment.color = "grey30")+
    geom_text(aes(label = Label), position = position_stack(vjust = .5), size = 4, color = "black") +
    #scale_fill_manual(values = c("#12a25e", "#ff9f0a")) +
    scale_fill_manual(
      values = c("KBAs Not Protected" = "#ff9f0a", "KBAs Protected" = "#12a25e"),
      breaks = c("KBAs Protected", "KBAs Not Protected" )   # legend order only
    )+
    labs(title = paste("Protection of Key Biodiversity Areas in", "\n", row_data$Name,  "(hectares, %)")) +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))
  
  # Show the chart
  #print(p)
  
  # --- Optional: Save each chart as a PNG file ---
  ggsave(filename = paste0(out_folder,"KBAPApie_", gsub(" ", "_", row_data$ID), ".png"), plot = p, width = 6, height = 6)
}



#IUCN category PA bar chart
# --- Reshape data for plotting ---
ha_fields <- c("Ia_HA", "Ib_HA", "II_HA", "III_HA", "IV_HA", "V_HA", "VI_HA", "Other_HA")
pct_fields <- c("Ia_pct", "Ib_pct", "II_pct", "III_pct", "IV_pct", "V_pct", "VI_pct", "Other_pct")

# --- Define colors for each category ---
custom_colors <- c(
  "Ia" = "#ff9f0A",
  "Ib" = "#7e361A",
  "II" = "#12A25E",
  "III" = "#ffd621",
  "IV" = "#b536b6",
  "V" = "#4f4ddc",
  "VI" = "#3fc8e4",
  "Other" = "#8c8c8c"
)

custom_labels <- c(
  "Ia" = "Ia- Strict nature reserve",
  "Ib" = "Ib- Wilderness area",
  "II" = "II- National park",
  "III" = "III- Natural monument or feature",
  "IV" = "IV- Habitat/species management area",
  "V" = "V- Protected landscape/seascape",
  "VI" = "VI- Protected area with sustainable use of natural resources",
  "Other" = "Other- Not reported, applicable, or assigned"
)
for (i in 1:nrow(data)) {
  
  # Extract current row
  row_data <- data %>% slice(i)

  # Reshape HA (area) values
  ha_data <- row_data %>%
    select(Name, all_of(ha_fields)) %>%
    pivot_longer(cols = -Name, names_to = "Metric", values_to = "Area") %>%
    mutate(Category = gsub("_HA", "", Metric)) %>%
    select(-Metric)
  
  # Reshape pct (percent) values
  pct_data <- row_data %>%
    select(Name, all_of(pct_fields)) %>%
    pivot_longer(cols = -Name, names_to = "Metric", values_to = "Percent") %>%
    mutate(Category = gsub("_pct", "", Metric)) %>%
    select(-Metric)
  
  # Merge the two long tables
  bar_data <- left_join(ha_data, pct_data, by = c("Name", "Category")) %>%
    mutate(
      Category = factor(Category, levels = gsub("_HA", "", ha_fields)),
      Area = ifelse(is.na(Area), 0, Area),
      Percent = ifelse(is.na(Percent), 0, Percent),
      Label = paste0(round(Percent, 0), "%")
    )
  #print(bar_data)
  
  # Plot the bar chart
  p <- ggplot(bar_data, aes(x = Category, y = Area, fill = Category)) +
    geom_col(width = 0.7) +
    geom_text(
      data = bar_data %>% filter(Area > 0),
      aes(x=Category, y= Area, label = Label),
      vjust = -0.5,
      size = 4,
      color = "black"
    ) +
    scale_fill_manual(values = custom_colors, labels= custom_labels) +
    labs(
      title = paste("Protected Area by IUCN Category in",  "\n", row_data$Name),
      x = "IUCN Category",
      y = "Area (ha)",
      fill = "IUCN Category"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.direction = "vertical",
      legend.box = "horizontal",
      legend.spacing.y = unit(0.2, "cm"),
      legend.justification = "left",
      legend.key.size = unit(1, "lines")
      
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.1)),
                       labels = comma,
                       #labels = label_number(accuracy = 1, big.mark = ",", scientific = FALSE),
                       
                       )  # add space for labels
  
  # Print the chart
  #print(p)
  
  # Optional: Save each chart
  ggsave(paste0(out_folder, "IUCNbar_", gsub(" ", "_", row_data$ID), ".png"), plot = p, width = 8, height = 8)
}