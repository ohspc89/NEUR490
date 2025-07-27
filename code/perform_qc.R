# perform_qc.R is an R script to perform quality checks
# on selected .txt files, which are ELAN output.
# The selection is based on 'reference.tsv', which is created
# from OneDrive folder's Excel spreadsheet, 'Reach_Coding_120524.xlsx'
# using fetch_ids.R.
# The script also makes use `qc.all()` prepared in qc_functions.R

# Before running this script, please ensure
#   1) the OneDrive folder: Reach & Grasp is synced
#   2) fetch_ids.R is run and 'references.tsv' is saved in /processed.
#   3) qc_functions.R is in the same folder as this script

# An elegant way to install packages
if (!(requireNamespace("Require", quietly = TRUE))) install.packages("Require")
package_list = c('fs', 'stringr', 'purrr')
Require::Require(package_list, require=T)

# This will return error if you did not complete 2) above.
# [JO] Folder naming nomenclature changed - 'path' column will have
# many duplicates.
references = read.csv('../processed/reference.tsv', sep='\t')
# Some problematic folders rejected for now (March 5, 2025)
subdirs_temp = references$path
idx_spare = !grepl("Data/TD27/TD27M3", subdirs_temp)
# [JO] Remove duplicates using `unique`
subdirs = unique(subdirs_temp[idx_spare])
# [JO] No longer in use - because folder naming nomenclature changed
# prefixes_temp = references$prefix
# prefixes = prefixes_temp[idx_spare]

# You also need to load this R script to use functions I wrote.
source('qc_functions.R')

# save the current working directory in case you need to revisit
your_wkdir = getwd()

################
# PATH details #
################

# User's HOME directory (ex. /Users/joh)
HOME = path_home()

# OneDrive specific
Mac_OneDrive_PATH = 'Library/CloudStorage/OneDrive-ChildrensHospitalLosAngeles/EEG reaching R01/Analysis/Behavior Coding/Reach & Grasp/Data'

# combine the two
user_path = paste0(HOME, '/', Mac_OneDrive_PATH)

# paths to .txt files
# ex) /Users/joh/Library/.../Data/TD17/TD17_M3
txtpaths = file.path(user_path, subdirs)

# [JO] Previous lines wouldn't work, because file/folder names have changed
# since I first wrote this script. These two lines should work.
# You need to make sure that each TD has only one coder's coding output
# ex. TD73-M5A6_AG.txt and TD73-M5A6_CC.txt must not stay together in 'TD73_M5' folder.
files <- dir_ls(txtpaths)                           # list all files in folders
txt_files <- files[str_detect(files, "\\.txt$")]    # filter the .txt files

# There can be different ways to report the quality check output.
# 1. You can create a long .log file.
#    Use `sink()` to log everything to a log file.
failed_files = character(0)

sink('../processed/quality_check_summary.log', append=TRUE, split=FALSE)
for (txt in txt_files){
    print(tail(str_split(txt, '/')[[1]], 1))
    # Logging improved - ChatGPT recommendation
    # Continue Processing even if one file fails
    result = tryCatch({
        qc.all(txt)
    }, error = function(e) {
        warning("Error processing:", txt, "; ", conditionMessage(e))
        assign("failed_files", c(failed_files, txt), envir=.GlobalEnv)
        return(NULL)
    })
    if (!is.null(result)) print(result)
}
sink()

writeLines(failed_files, '../processed/failed_files.log')

# 2. You can prepare separate output files for the three types of check
#    This will be done not on failed files
successful_files = txt_files[!txt_files %in% failed_files]

# Will save .txt filename if the last_offsets are not unique.
# ('$last_offsets_match' is FALSE)
offset_issue = character(0)
# Will save .txt filename, tier, rows (prev-next), prev_value, next_value
# if prev_value and next_value are not identical
# ('$continuously_coded' has one or more elements
#   and the values are not "No oneset-offset mismatch found")
cont_issue = matrix(NA, ncol=5)
# will save .txt filename, row#, label
# if labels are not provided in the uppercase or not following the rule.
# ('$proper_label' has 1 or more rows)
proper_issue = matrix(NA, ncol=3)

for (txt in successful_files){
    outlist = qc.all(txt)
    # ex. TD13-M3_A3R2_CC.txt
    key = tail(str_split(txt, '/')[[1]], 1)
    # If $last_offsets_match is FALSE, .txt filename is saved.
    if (!(outlist$last_offsets_match))
        offset_issue = c(offset_issue, key)
    cont_check = outlist$continuously_coded
    # Even if there's only one occasion of the mismatch,
    # as long as it is not the info message,
    # it will be processed.
    if (!(length(cont_check) == 1 &&
          cont_check == "No onset-offset mismatch found")){
        # `msg` in the format (see qc_functions.R for more detail):
        # "Tier: {\s}+; rows: [0-9]+\-[0-9]+; values differ: [0-9]+ vs. [0-9]+"
        # Split `msg` by '; ' first -> have three parts
        #   (1) "Tier: {\s}+"
        #   (2) "rows: [0-9]+\-[0-9]+
        #   (3) "values differ: [0-9]+ vs. [0-9]+"
        # Split each of (1) and (2) by ': ' and save the second part
        #   (1a) {\s}+              ex. "LA"
        #   (2a) [0-9]+\-[0-9]+     ex. "19-20"
        # Split (3) by ' vs. ' and save the two values
        #   (3a) [0-9]+             ex. "59700"
        #   (3b) [0-9]+             ex. "60640"
        for (msg in cont_check){
            bunch = str_split(msg, '; ')[[1]]
            tier = str_split(bunch[1], ': ')[[1]][2]
            rows = str_split(bunch[2], ': ')[[1]][2]
            vs_vals = str_split(str_split(bunch[3], ': ')[[1]][2],
                                ' vs. ')[[1]]
            prev_value = vs_vals[1]
            next_value = vs_vals[2]
            cont_issue = rbind(cont_issue,
                               c(key, tier, rows, prev_value, next_value))
        }
    }
    # If $proper_labels has one or more valid rows,
    # save .txt filename, row number of a label, and the label
    proper_check = outlist$proper_labels
    n_p = nrow(proper_check)
    if (n_p > 0){
        for (j in 1:n_p){
            proper_issue = rbind(proper_issue,
                                 c(key,
                                   as.numeric(row.names(proper_check[j,])),
                                   proper_check[j, 1]))
        }
    }
}
# First rows are NA's. Remove them
cont_issue = cont_issue[-1, ]
proper_issue = proper_issue[-1, ]

# Convert matrices into data frames
# so that we can have the columns named.
lastoffset = data.frame(filename=offset_issue)
write.table(lastoffset, '../processed/qc_offset.tsv', sep='\t',
            row.names=F, col.names=T, quote=F)
continuous = data.frame(cont_issue)
colnames(continuous) = c('filename', 'tier', 'rows',
                         'prev_value', 'next_value')
write.table(continuous, '../processed/qc_continuous.tsv', sep='\t',
            row.names=F, col.names=T, quote=F)
properlabels = data.frame(proper_issue)
colnames(properlabels) = c('filename', 'row', 'label')
write.table(properlabels, '../processed/qc_labels.tsv', sep='\t',
            row.names=F, col.names=T, quote=F)
