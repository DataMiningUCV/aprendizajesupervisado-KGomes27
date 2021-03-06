####################################################################################
#Install packages
install = function(pkg){
  # Si ya est\'a instalado, no lo instala.
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "http:/cran.rstudio.com", dependencies = TRUE)
    if (!require(pkg, character.only = TRUE)) stop(paste("load failure:", pkg))
  }
}

packages <- c("xlsx", "stats");
for (i in packages){
  install(i)
}

(.packages())

######################################################################################
#Load data
hogares = read.xlsx(file = "./hogares.xlsx", sheetIndex = 1,
                    as.data.frame=TRUE, header=TRUE, rowIndex = NULL,
                    startRow = 1, endRow = 104, stringsAsFactors=FALSE)

#head(hogares)

names(hogares) <- c("distrito", "direccion", "tipo", "piso",
                    "descripcion", "habitaciones", "precio", "foto", "notas")

####################################################################################
#####################PREPROCESSING DATA#############################################
#Delete column foto y piso
hogares = subset(x = hogares, select = c("distrito", "direccion", "tipo", "descripcion",
                                         "habitaciones", "precio", "notas"))

#Eliminar \n de columna direccion y distrito
hogares$direccion = gsub("\n", " ", hogares$direccion)
hogares$distrito = gsub("\n", " ", hogares$distrito)

hogares$direccion[11] = "Galliate"
hogares$direccion[33] = "Via San Roberto Belarmino"
hogares$direccion[61] = "Via di Monte Verde"
  
#Agregamos la columna tiempo al df - tiempo desde columna direccion a destino
hogares$tiempo = 0
names(hogares)

#Convertir columna direcccion en tiempo usando google_api.r
# Seleccionar google_api.R en su sistema de archivos
source(file.choose())

# Colocar su API Key 
api_key = "AIzaSyANSFEQzoBtSrKw--5mYLHfpw0-LSTH7Wc"

destino = c("Piazzale Aldo Moro") #real destiny

#i = 4

for(i in 1:nrow(hogares)){
  #origen es columna direccion
  origen = paste(hogares$direccion[i], hogares$distrito[i], "Roma", sep = " ")
  
  api_url = get_url(origen, destino, api_key)
  
  json = get_data(api_url)
  
  jsondf = parse_data(json)
  
  if(jsondf$status == "OK") {
    #transformamos duration.text en segundos
    findH = grepl(pattern = "[0-9]+h", x = jsondf$duration$text)
    time = 0
    if (findH == TRUE){
      noH = strsplit(x = jsondf$duration$text, split = "h") #duration.text sin "h"
      time = as.integer(noH[[1]][1]) * 60 #horas en minutos
      min = as.integer(strsplit(x = noH[[1]][2], split = "min"))
      time = (time + min) * 60 #minutos a segundos
    }else {
      time = as.integer(strsplit(x = jsondf$duration$text, split = "min")) * 60
    }
    time
    hogares$tiempo[i] = time
  }
}

#Convertir columna 'tipo' a numerico
#1 - Appartamento, 2 - Mini Appartamento, 3 - Monolocale
hogares$tipo[61] = hogares$tipo[85] = hogares$tipo[7] = hogares$tipo[27] = "Appartamento"
hogares$tipo[37] = hogares$tipo[103] = "Mini appartamento"
hogares$tipo[hogares$tipo == "Appartamento"] =1
hogares$tipo[hogares$tipo == "Mini appartamento"] = 2
hogares$tipo[hogares$tipo == "Monolocale"] = 3
hogares$tipo = as.numeric(hogares$tipo)

#Convertir columna notas a numerico
#1 - ragazzi (hombres), 2 - ragazze (mujeres), 3 - Both
for(i in 1:nrow(hogares)){
  findM = grepl(pattern = "ragazzi", x = hogares$notas[i])
  findF = grepl(pattern = "ragazze", x = hogares$notas[i])
  if ((findM == TRUE) && (findF == TRUE)) {
    hogares$notas[i] = 3
  }else if (findM == TRUE) {
    hogares$notas[i] = 1
  }else if (findF == TRUE) {
    hogares$notas[i] = 2
  }
}
##"APT da condividere con i proprietari Metro B San Paolo Autobus 716, 769, 792"
hogares$notas[39] = 3
hogares$notas = as.numeric(hogares$notas)

#Convertir precio a numerico
hogares$servicios = 0
hogares[nrow(hogares) + 1,]
hogares$precio = gsub("�,�", "$", hogares$precio)
hogares$precio = gsub("\n", " ", hogares$precio)
hogares$calefaccion = 0
hogares$condominio = 0

for (i in 1:nrow(hogares)) {
  if ((grepl(pattern = "riscaldamento", x = hogares$precio[i]) == TRUE)) {
    hogares$calefaccion[i] = 1
  }
  if ((grepl(pattern = "condominio", x = hogares$precio[i]) == TRUE)) {
    hogares$condominio[i] = 1
  }
  price = strsplit(x = hogares$precio[i], split = ";") #Dividir campo
  for (j in 1:length(price[[1]])) {
    findPrice = grepl(pattern = "[0-9]+", x = price[[1]][j]) #Verificar si es precio o servicio
    if (findPrice == TRUE) {
      splitPrice = strsplit(x = price[[1]][j], split=" ")
      if ((grepl(pattern = "TUTTO INCLUSO", x = price[[1]][j]) == TRUE) || 
          (grepl(pattern = "Tutto incluso", x = price[[1]][j]) == TRUE)) {
        hogares$servicios[i] = 2
        hogares$precio[i] = splitPrice[[1]][2]
      }else if ((grepl(pattern = "condominio e acqua inclusi", x = price[[1]][j]) == TRUE)){
        hogares$servicios[i] = 3
        hogares$precio[i] = splitPrice[[1]][2]
      }else if (grepl(pattern = "[0-9]+", x = splitPrice[[1]][2])) {
        hogares$precio[i] = splitPrice[[1]][2]
      }
    }else if (grepl(pattern = "spese escluse", x = price[[1]][j]) == TRUE) {
      hogares$servicios[i] = 1
    }else if (grepl(pattern = "TUTTO INCLUSO", x = price[[1]][j]) == TRUE) {
      hogares$servicios[i] = 2
    }else {
      hogares$servicios[i] = 3
    }
  }
}

hogares$precio[43] = 450
hogares$precio[24] = 380
hogares$precio[61] = 425
hogares$precio[53] = 425
hogares$precio = as.numeric(hogares$precio)

#Convertir habitaciones a numerico
hogares$habitaciones = gsub("\n", " ", hogares$habitaciones)

hogares$habitaciones[hogares$habitaciones == "1 singola"] = 1
hogares$habitaciones[hogares$habitaciones == "1 Singola"] = 1
hogares$habitaciones[hogares$habitaciones == "1 singole"] = 1
hogares$habitaciones[hogares$habitaciones == "1 Singole"] = 1
hogares$habitaciones[hogares$habitaciones == "1 doppia e/o uso singola"] = 1
hogares$habitaciones[hogares$habitaciones == "1 Singola / uso doppia"] = 1
hogares$habitaciones[hogares$habitaciones == "1 singola con bagno privato"] = 1
hogares$habitaciones[hogares$habitaciones == "1 singola/uso doppia"] = 1
hogares$habitaciones[hogares$habitaciones == "1 singola/uso doppia;"] = 1

hogares$habitaciones[hogares$habitaciones == "2 singole"] = 2
hogares$habitaciones[hogares$habitaciones == "1 singola; 1 doppia"] = 2
hogares$habitaciones[hogares$habitaciones == "1 singola; 1 posto letto"] = 2
hogares$habitaciones[hogares$habitaciones == "1 singola; 1 doppia;"] = 2

hogares$habitaciones[hogares$habitaciones == "3 singola"] = 3
hogares$habitaciones[hogares$habitaciones == "3 singole"] = 3
hogares$habitaciones[hogares$habitaciones == "3 singole con bagno privato"] = 3
hogares$habitaciones[hogares$habitaciones == "2 singole; 1 doppia"] = 3

hogares$habitaciones[hogares$habitaciones == "4 singole"] = 4

hogares$habitaciones[hogares$habitaciones == "Intero Appartamento"] = 5
hogares$habitaciones[hogares$habitaciones == "Intero appartamento"] = 5
hogares$habitaciones[hogares$habitaciones == "intero appartamento"] = 5

hogares$habitaciones[hogares$habitaciones == "Mini Appartamento"] = 6

hogares$habitaciones[hogares$habitaciones == "monolocale"] = 7

hogares$habitaciones[hogares$habitaciones == "1 posto letto"] = 8

hogares$habitaciones[hogares$habitaciones == "1 doppia"] = 9

hogares$habitaciones[hogares$habitaciones == "2 doppie"] = 10

hogares$habitaciones = as.numeric(hogares$habitaciones)

#Convertir descripcion a numerico
hogares$entrada = 0
hogares$habitacion = 0
hogares$cocina = 0

hogares$descripcion = gsub("\n", " ", hogares$descripcion)

for (i in 1:nrow(hogares)) {
  if ((grepl(pattern = "Ingresso", x = hogares$descripcion[i]) == TRUE) ||
      (grepl(pattern = "ingresso", x = hogares$descripcion[i]) == TRUE)) {
    hogares$entrada[i] = 1
  }
  if ((grepl(pattern = "camera", x = hogares$descripcion[i]) == TRUE)) {
    hogares$habitacion[i] = 1
  }
  if ((grepl(pattern = "cucina", x = hogares$descripcion[i]) == TRUE)) {
    hogares$cocina[i] = 1
  }
}

hogares$entrada = as.numeric(hogares$entrada)
hogares$habitacion = as.numeric(hogares$habitacion)
hogares$cocina = as.numeric(hogares$cocina)
hogares$condominio = as.numeric(hogares$condominio)
hogares$calefaccion = as.numeric(hogares$calefaccion)

#Eliminar columnas que no seran usadas
hogares = subset(x = hogares, select = c("tipo", "habitaciones", "precio", "notas",
                                         "tiempo", "servicios", "calefaccion", "condominio",
                                         "entrada", "habitacion", "cocina"))
names(hogares) = c("tipo", "habitaciones", "precio", "sexo",
                   "tiempo", "servicios", "calefaccion", "condominio",
                   "entrada", "habitacion", "cocina")

#Seleccionar mujeres
hogaresMujeres = subset(x = hogares, subset = sexo!=1)
regression = lm(formula = hogaresMujeres$precio ~ ., data = hogaresMujeres)

plot(regression)

predictions = predict(regression)

plot(hogaresMujeres$precio, col="red")
par(new=TRUE) 

plot(predictions)

mean(abs(predictions - hogaresMujeres$precio))

#Seleccionar hombres
hogaresHombres = subset(x = hogares, subset = sexo!=2)

regression = lm(formula = hogaresHombres$precio ~ ., data = hogaresHombres)

#plot(regression)

predictions = predict(regression)

plot(hogaresHombres$precio, col="red")
par(new=TRUE) 
plot(predictions, col="blue")

mean(abs(predictions - hogaresHombres$precio))

#Seleccionando el mejor hogar
hogares$ranking = 0
promPrecio = mean(hogares$precio)
promTiempo = mean(hogares$tiempo)

for (i in 1:nrow(hogares)) {
  if(hogares$tipo[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 500
  }else if(hogares$tipo[i] == 2) {
    hogares$ranking[i] = hogares$ranking[i] + 250
  }else if(hogares$tipo[i] == 3) {
    hogares$ranking[i] = hogares$ranking[i] + 125
  }
  
  if(hogares$precio[i] <= promPrecio) {
    hogares$ranking[i] = hogares$ranking[i] + 200
  }
  
  if(hogares$tiempo[i] <= promTiempo) {
    hogares$ranking[i] = hogares$ranking[i] + 100
  }
  
  if(hogares$servicios[i] == 2) {
    hogares$ranking[i] = hogares$ranking[i] + 100
  }else if(hogares$servicios[i] == 3) {
    hogares$ranking[i] = hogares$ranking[i] + 50
  }
  
  if(hogares$calefaccion[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 10
  }
  
  if(hogares$condominio[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 10
  }
  
  if(hogares$entrada[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 10
  }
  
  if(hogares$habitacion[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 10
  }
  
  if(hogares$cocina[i] == 1) {
    hogares$ranking[i] = hogares$ranking[i] + 10
  }
}
