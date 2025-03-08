##########################
# Packages: install/load #
##########################
# Require: Installing and Loading R packages for Reproducible Workflows
# stringr: play a big role in many data cleaning and prep tasks
# readxl: makes it easy to get data out of Excel

# These lines are to load packages and install if necessary.
# Do not worry if you dont' understand.
if (!requireNamespace("Require", quietly = T)) install.packages("Require")
package_list = c('readxl', 'stringr', 'fs')
Require::Require(package_list, require=T, cranCache=T)

################################
# Reading xlsx file:           #
#   - Reach_Coding_120524.xlsx #
################################

# Column names of the excel sheet
colnames = c('ID', 'CODER', 'Priority',
             paste0('M1', c('#_of_trials', paste0('A', 2:7))),
             paste0('M2', c('#_of_trials', paste0('A', 2:7))),
             paste0('M3', c('#_of_trials', paste0('A', 2:7))),
             paste0('M4', c('#_of_trials', paste0('A', 2:7))),
             paste0('M5', c('#_of_trials', paste0('A', 2:7))))

# path shall be updated - to reflect the actual path
HOME = fs::path_home()
Mac_OneDrive = 'Library/CloudStorage/OneDrive-SharedLibraries-ChildrensHospitalLosAngeles/Smith, Beth - Reach & Grasp'
excel_file = 'Reach_Coding_120524.xlsx'

onedrive_path = file.path(HOME, Mac_OneDrive, excel_file)

# sheet='CC'
if (!file.exists(onedrive_path)){
    stop("Error: Excel file not found at: ", onedrive_path)
}
record = read_excel(onedrive_path, sheet='CC', skip=1)
colnames(record) = colnames

#############################################
# Data Wrangling:                           #
#   - actual information extraction happens #
#############################################

# M3, M4 entries - S:X, Z:AE, or 19:24, 25:31
m34 = record[,c(1, 19:24, 25:31)]
m34colnames = colnames(m34)

subj = vector()     # ex. TD17
months = vector()   # ex. M3
acts = vector()     # ex. A4
prefixes = vector() # ex. TD17-M3_A4
                    # full filename ex: TD17-M3_A4R3_CC.txt
paths = vector()    # ex. TD17/TD17M3/TD17M3A4
for (i in 1:dim(m34)[1]){
    row = m34[i,]       # `row` is a tibble
    for (j in 2:length(row)){
        if (row[j] %in% c('X', 'x')){
            subjstr = row[1]$ID
            # `stringr::str_split()` splits a string into pieces
            temp = str_split(m34colnames[j], "")[[1]]
            # `stringr::str_c()` joins multiple strings into one
            monstr = str_c(temp[1], temp[2])
            astr = str_c(temp[3], temp[4])
            txtstr = str_c(subjstr, '-',
                           monstr, '_',
                           astr)
            # `stringr::str_c()` is very similar to `paste0()`
            # so you can join strings in the following way.
            pathstr = file.path('Data', subjstr,
                                paste0(subjstr, monstr),
                                paste0(subjstr, monstr, astr))
            # add items to vectors
            subj = c(subj, subjstr)
            months = c(months, monstr)
            acts = c(acts, astr)
            prefixes = c(prefixes, txtstr)
            paths = c(paths, pathstr)
        }
    }
}

# Reference table looks like...
# +------+-------+-----+------------+---------------------------+
# | subj | month | act | prefix     | path                      |
# |------|-------|-----|------------|---------------------------|
# | TD17 | M3    | A2  | TD17-M3_A2 | Data/TD17/TD17M3/TD17M3A2 |
# |------|-------|-----|------------|---------------------------|
# | ...  | ...   | ... | ...        | ...                       |
tab = data.frame(subj=subj,
                 month=months,
                 act=acts,
                 prefix=prefixes,
                 path=paths)

# save the reference to a tab separated file
write.table(tab, file='../processed/reference.tsv', sep= "\t",
            row.names=F, col.names=T,
            quote=F)
