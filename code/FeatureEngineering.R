library(FactoMineR)
library(factoextra)
library(tidyverse)

# Load data
data <- read_csv("/data/processed_data.csv")

data1 <- data %>%
  select(-c(NRD_VisitLink,KEY_NRD,NRD_DaysToEvent)) %>%
  na.omit() %>%
  mutate_at(vars(ZIPINC_QRTL:CM_WGHTLOSS), as.factor) %>%
  mutate(HCUP_ED=ifelse(HCUP_ED>0, 1, HCUP_ED),
         SAMEDAYEVENT=ifelse(SAMEDAYEVENT>0, 1, SAMEDAYEVENT),
         HCUP_ED=as.factor(HCUP_ED),
         SAMEDAYEVENT=as.factor(SAMEDAYEVENT),
         AWEEKEND=as.factor(AWEEKEND),
         DISPUNIFORM=as.factor(DISPUNIFORM),
         FEMALE=as.factor(FEMALE),
         ORPROC=as.factor(ORPROC),
         PAY1=as.factor(PAY1),
         PL_NCHS=as.factor(PL_NCHS),
         REHABTRANSFER=as.factor(REHABTRANSFER))


dat_train <- data1 %>%
  select(1,4, 7:10, 16, 5, 13, 17, 2, 3, 6, 11, 12, 14, 15, 18:47)
str(dat_train)

dat_train1 <- dat_train[1:100000,]

# Apply Multi-factor Analysis (MFA) to determine important features
res.mfa <- MFA(dat_train[sample(nrow(dat_train),50000)],
               group=c(1,1,4,1,3,7,30),
               type=c("s","s","s","s","n","n","n"),
               name.group=c("age","month", "clinical", "cost","demographic cat", "inpatient cat","conditions cat"))
res.mfa
eig.val <- get_eigenvalue(res.mfa)
head(eig.val)
fviz_screeplot(res.mfa)
group <- get_mfa_var(res.mfa,"group")
group
head(group$correlation)
fviz_mfa_var(res.mfa, "group")
# Contribution to the first dimension
fviz_contrib(res.mfa, "group", axes = 1)
# Contribution to the second dimension
fviz_contrib(res.mfa, "group", axes = 2)
quanti.var <- get_mfa_var(res.mfa, "quanti.var")
quanti.var 
# Coordinates
head(quanti.var$coord)
# Cos2: quality on the factore map
head(quanti.var$cos2)
# Contributions to the dimensions
head(quanti.var$contrib)
fviz_mfa_var(res.mfa, "quanti.var", palette = "jco", 
             col.var.sup = "violet", repel = TRUE)
fviz_mfa_var(res.mfa, "quanti.var", palette = "jco", 
             col.var.sup = "violet", repel = TRUE,
             geom = c("point", "text"), legend = "bottom")
# Contributions to dimension 1
fviz_contrib(res.mfa, choice = "quanti.var", axes = 1, top = 20,
             palette = "jco")
# Contributions to dimension 2
fviz_contrib(res.mfa, choice = "quanti.var", axes = 2, top = 20,
             palette = "jco")
fviz_mfa_var(res.mfa, "quanti.var", col.var = "contrib", 
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"), 
             col.var.sup = "violet", repel = TRUE,
             geom = c("point", "text"))
# Color by cos2 values: quality on the factor map
fviz_mfa_var(res.mfa, col.var = "cos2",
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"), 
             col.var.sup = "violet", repel = TRUE)
fviz_cos2(res.mfa, choice = "quanti.var", axes = 1)
fviz_cos2(res.mfa, choice = "quanti.var", axes = 2)

#MFA analysis shows that demographic categorical variables such as income quartile, location, and gender are not important, hence we will remove these features before modeling.

# Remove unimportant features and save data for modeling
data1 %>% select(-c("FEMALE","ZIPINC_QRTL","PL_NCHS")) %>% write_csv("data/engineered_data.csv")