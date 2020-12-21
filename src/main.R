library(dplyr)
library(ggplot2)
library(tidyr)

# Loading the keyboard keys coordinates
# (manually generated using Matlab script `mark_coordinates.m`)
key_coor <- read.csv2('./data/keyboard_keys_coordinates.csv', stringsAsFactors = F, dec = '.') %>% 
    add_row(index = 32, x = 302.38, y =  27.52, plus_shift = 0) %>% 
    add_row(index = 13, x = 550.23, y = 106.89, plus_shift = 0)

# Loading the keyboard key/index relation (it is easier to work with the numerical key representations)
key_codes <- read.csv2('./data/key_char_index_relation.csv', stringsAsFactors = F) %>% 
    add_row(index = 32, char = ' ') %>% 
    left_join(key_coor,  by = 'index') 

# Read and process the `birds_talk.txt` twitter dataset.
# The 'clean' dataset has it's dates removed, which I will use to add to my dataset.
# Every row contains a series of characters pressed on 
# the keyboard by landing or hopping birds.
tjierp1 <- read.delim('./data/birds_talk.txt',
                      header = F, col.names = 'char', stringsAsFactors = F)

# One column: 'char' exists at this point.
# Adding the next row 'date' values to the current row as a new column.
# (because current data looks like "<message>\n<date>\n<message>\n<date>" etc.)
# Then only remain all rows with an actual date in the 'time' field.
# Results in columns 'char', 'time'
tjierp2 <- tjierp1 %>% 
    mutate(time = lead(char)) %>% 
    filter(grepl('^..?\\s...\\s....$', time))

# Creating a row per day (18 days total).
# Results in columns 'time', 'char'
tjierp3 <- tjierp2 %>% 
    group_by(time) %>% 
    summarise(char = paste0(collapse = '\\n', char))

# Creating a row per character (91691 chars in total)
# Results in columns 'time', 'char'
tjierp4 <- data.frame()
for (iRow in seq_len(nrow(tjierp3))) {
    spread_char <- strsplit(tjierp3$char[iRow], split = '')
    tjierp4 <- rbind(tjierp4,
                     data.frame(time = tjierp3$time[iRow],
                                char = spread_char[[1]],
                                stringsAsFactors = F))
}

# Checking the number of 'shift' + '...' characters
# Since we need to exclude 'caps lock' characters, we can only work with '~!@#$%^&*()_+{}:"|<>?'
shift_chars <- tjierp4 %>%
    group_by(char) %>% 
    summarize(char = char[1], 
              n = n()) %>% 
    filter(grepl('[~!@#$%^&*()_+{}:"|<>?]', char))
# Only ':@^_' exist in this set:
# 
#  char  |   n
# _______|_______
#   :        1
#   @        5
#   ^        5
#   _       11

# Shift hold indexes:
shift_indexes <- (key_codes %>% filter(grepl('[~!@#$%^&*()_+{}:"|<>?]', char)))$index

# Due to splitting on every character, the \\n will become a '\\' and 'n'.
# This is reverted here and the 'key_codes' with the key coordinate is added.
tjierp <- tjierp4 %>% 
    mutate(after = lead(char),
           char  = ifelse(char == '\\' & after == 'n',
                          '\\n', char)) %>% 
    filter(lag(char) != '\\n') %>% 
    select(-after) %>% 
    left_join(key_codes, by = 'char') %>% 
    mutate(time = ifelse(grepl('^.\\s', time), 
                         paste0('0', time), time))


## Different plots of the data, and further data shaping to support that.


# For plotting purposes, a random offset is applied 
# to the source and destination coordinates to create a type of heat map.
tjierp_r <- tjierp %>% 
    mutate(x_r = x + rnorm(nrow(.), sd = 10),
           y_r = y + rnorm(nrow(.), sd = 10)) %>% 
    group_by(msg_nr = cumsum(index == 13)) %>% 
    mutate(x_r_lead = lead(x_r),
           y_r_lead = lead(y_r)) %>% 
    ungroup()

# Plot a random set of 1000 of these jumps.
ggplot(sample_n(tjierp_r, 1000), aes(x = x_r, y = y_r, 
                     xend = x_r_lead, yend = y_r_lead)) +
    geom_curve(alpha = 0.005, curvature = 0.3) +
    theme(line  = element_blank(),
          text  = element_blank(),
          title = element_blank()) +
    coord_equal(ylim = c(-10, 270)) +
    labs(x = '', y = '')
ggsave('tjierp_r.pdf')

time_ids <- data.frame() %>% 
    transmut(data.frame(time = sort(unique(tjierp$time))),
                   time_id = row_number())

# Set with 1 row per key combination (1 in each direction) containing summary of all data
tjierp_u <- tjierp %>% 
    left_join(time_ids, by = 'time') %>% 
    mutate(index = ifelse(plus_shift, index, NA),
           x_lead = ifelse(plus_shift, lead(x), NA),
           y_lead = ifelse(plus_shift, lead(y), NA),
           index_lead = lead(index),
           # paste 2 indexes together, always lowest first, then highest.
           key = ifelse(index < index_lead, paste(index, index_lead), paste(index_lead, index))) %>% 
    ungroup() %>% 
    group_by(index) %>% 
    mutate(n_total = n()) %>% 
    ungroup() %>% 
    group_by(key) %>% 
    summarise(x = x[1], y = y[1], 
              x_lead = x_lead[1], y_lead = y_lead[1], plus_shift = plus_shift[1],
              n_total = n_total[1], index = as.character(index[1]), index_lead = index_lead[1], time_id = time_id[1],
              n = n()) %>% 
    ungroup() %>%
    filter(!is.na(key),
           !(x == x_lead & y == y_lead),  # Removes double button presses
           !index %in% c(104))


ggplot(tjierp_u, aes(x = x,
                     y = y,
                     xend = x_lead,
                     yend = y_lead,
                     size = n/n_total,
                     alpha = n/n_total,
                     col = index)) +
    geom_curve(curvature = 0.3, lineend = 'round') +
    coord_equal(ylim = c(-10, 300)) +
    theme(line  = element_blank(),
          text  = element_blank(),
          title = element_blank()) +
    labs(x = '', y = '') +
    geom_point(inherit.aes = FALSE,
               data = filter(key_codes, plus_shift == 0), 
               mapping = aes(x = x, y = y), alpha = 0.8, size = 8, fill = 'white', stroke = 2, shape = 21) +
    geom_text(inherit.aes = FALSE,
              data = filter(key_codes, plus_shift == 0), mapping = aes(x = x-0.5, y = y+1, label = char))

ggsave('tjierp_u_while_capslock_enabled.pdf')


# Only plot 
ggplot(
    filter(tjierp_u, index %in% shift_indexes),
    aes(x = x,
        y = y,
        xend = x_lead,
        yend = y_lead,
        size = n/n_total,
        alpha = n/n_total,
        col = index)) +
    geom_curve(curvature = 0.3, lineend = 'round') +
    coord_equal(ylim = c(-10, 300)) +
    theme(line  = element_blank(),
          text  = element_blank(),
          title = element_blank()) +
    labs(x = '', y = '') +
    geom_point(inherit.aes = FALSE,
               data = filter(key_codes, plus_shift == 0), 
               mapping = aes(x = x, y = y), alpha = 0.8, size = 8, fill = 'white', stroke = 2, shape = 21) +
    geom_text(inherit.aes = FALSE,
              data = filter(key_codes, plus_shift == 0), mapping = aes(x = x-0.5, y = y+1, label = char))
