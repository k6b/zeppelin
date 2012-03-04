-- MySQL dump 10.14  Distrib 5.3.3-MariaDB-rc, for unknown-linux-gnu (x86_64)
--
-- Host: sql    Database: zeppelin_test
-- ------------------------------------------------------
-- Server version	5.3.3-MariaDB-rc-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `backups`
--

DROP TABLE IF EXISTS `backups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `backups` (
  `id` int(8) NOT NULL,
  `name` varchar(15) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_date` varchar(10) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_time` varchar(14) COLLATE utf8_unicode_ci DEFAULT NULL,
  `server` int(8) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `backups`
--

LOCK TABLES `backups` WRITE;
/*!40000 ALTER TABLE `backups` DISABLE KEYS */;
INSERT INTO `backups` VALUES (19186905,'daily','2012-02-25','04:32:52-06:00',20574083),(19186402,'daily','2012-02-25','04:25:25-06:00',20594905),(19044036,'daily','2012-02-21','04:15:12-06:00',20586311),(18969547,'weekly','2012-02-19','04:23:51-06:00',20574083),(18969529,'weekly','2012-02-19','04:22:36-06:00',20574080),(18969057,'weekly','2012-02-19','04:17:05-06:00',20608527),(18968991,'weekly','2012-02-19','04:15:21-06:00',20586311),(18968997,'weekly','2012-02-19','04:16:29-06:00',20594905),(19186539,'daily','2012-02-25','04:30:18-06:00',20608527),(19186872,'daily','2012-02-25','04:32:24-06:00',20574080),(19186383,'daily','2012-02-25','06:17:35-06:00',20586311),(19153217,'daily','2012-02-24','06:15:59-06:00',20586311);
/*!40000 ALTER TABLE `backups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `distros`
--

DROP TABLE IF EXISTS `distros`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `distros` (
  `id` int(10) NOT NULL,
  `distro` char(45) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `distros`
--

LOCK TABLES `distros` WRITE;
/*!40000 ALTER TABLE `distros` DISABLE KEYS */;
INSERT INTO `distros` VALUES (112,'Ubuntu 10.04 LTS'),(81,'Windows Server 2008 R2 x64 - SQL Web'),(58,'Windows Server 2008 R2 x64 - MSSQL2K8R2'),(100,'Arch 2011.10'),(31,'Windows Server 2008 SP2 x86'),(108,'Gentoo 11.0'),(109,'openSUSE 12'),(24,'Windows Server 2008 SP2 x64'),(110,'Red Hat Enterprise Linux 5.5'),(57,'Windows Server 2008 SP2 x64 - MSSQL2K8R2'),(111,'Red Hat Enterprise Linux 6'),(120,'Fedora 16'),(119,'Ubuntu 11.10'),(116,'Fedora 15'),(56,'Windows Server 2008 SP2 x86 - MSSQL2K8R2'),(114,'CentOS 5.6'),(115,'Ubuntu 11.04'),(103,'Debian 5 (Lenny)'),(104,'Debian 6 (Squeeze)'),(118,'CentOS 6.0'),(28,'Windows Server 2008 R2 x64'),(106,'Fedora 14');
/*!40000 ALTER TABLE `distros` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `flavors`
--

DROP TABLE IF EXISTS `flavors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flavors` (
  `id` int(2) NOT NULL,
  `flavor` varchar(25) COLLATE utf8_unicode_ci DEFAULT NULL,
  `ram` int(5) DEFAULT NULL,
  `disk` int(4) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `flavors`
--

LOCK TABLES `flavors` WRITE;
/*!40000 ALTER TABLE `flavors` DISABLE KEYS */;
INSERT INTO `flavors` VALUES (1,'256 server',256,10),(2,'512 server',512,20),(3,'1GB server',1024,40),(4,'2GB server',2048,80),(5,'4GB server',4096,160),(6,'8GB server',8192,320),(7,'15.5GB server',15872,620),(8,'30GB server',30720,1200);
/*!40000 ALTER TABLE `flavors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servers`
--

DROP TABLE IF EXISTS `servers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `servers` (
  `id` int(8) NOT NULL,
  `hostname` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `distro` int(4) DEFAULT NULL,
  `public_ip` varchar(15) COLLATE utf8_unicode_ci DEFAULT NULL,
  `private_ip` varchar(15) COLLATE utf8_unicode_ci DEFAULT NULL,
  `flavor` int(1) DEFAULT NULL,
  `status` varchar(15) COLLATE utf8_unicode_ci DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `servers`
--

LOCK TABLES `servers` WRITE;
/*!40000 ALTER TABLE `servers` DISABLE KEYS */;
INSERT INTO `servers` VALUES (20574080,'ns1.breakallthethings.com',104,'50.56.221.164','10.179.19.78',1,'ACTIVE'),(20574083,'ns2.breakallthethings.com',104,'50.56.199.249','10.179.19.79',1,'ACTIVE'),(20586311,'sandbox.breakallthethings.com',100,'50.56.203.227','10.179.35.105',3,'ACTIVE'),(20594905,'relay.breakallthethings.com',118,'108.166.65.37','10.179.41.135',2,'ACTIVE'),(20608527,'sql.0x2a.co',100,'50.56.203.10','10.179.32.134',2,'ACTIVE'),(20630554,'perlmfapitest',100,'108.166.78.214','10.179.45.117',1,'BUILD');
/*!40000 ALTER TABLE `servers` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-02-26 12:52:36
